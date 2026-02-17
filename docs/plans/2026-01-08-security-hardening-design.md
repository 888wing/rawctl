# Security Hardening Design

針對開源後的 API 安全強化措施設計。

## 1. Rate Limiting（速率限制）

### 策略設計

| 層級 | 限制 | 時間窗口 | 適用範圍 |
|------|------|----------|----------|
| Global | 1000 req | 1 min | 所有 IP |
| Per-IP | 100 req | 1 min | 未認證請求 |
| Per-User | 300 req | 1 min | 已認證用戶 |
| Per-Endpoint | 見下表 | - | 敏感操作 |

### 敏感端點限制

```yaml
/auth/login:        5 req/min per IP      # 防暴力破解
/auth/register:     3 req/hour per IP     # 防批量註冊
/auth/refresh:      10 req/min per user   # Token 刷新
/nano-banana/*:     20 req/min per user   # AI 處理（成本高）
/checkout/*:        10 req/min per user   # 支付相關
```

### 回應標頭

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1704700800
Retry-After: 60  # 當被限制時
```

### 後端實現（建議）

```typescript
// Redis-based sliding window
interface RateLimitConfig {
  key: string;           // e.g., "rate:ip:192.168.1.1" or "rate:user:uuid"
  limit: number;
  windowMs: number;
}

// 使用 Redis MULTI/EXEC 確保原子性
async function checkRateLimit(config: RateLimitConfig): Promise<{
  allowed: boolean;
  remaining: number;
  resetAt: number;
}>;
```

---

## 2. Request Signing（請求簽名）

### 適用場景

僅對**敏感操作**啟用，避免增加所有請求的複雜度：

- Nano Banana AI 處理
- 點數消費操作
- 帳戶設定變更

### 簽名算法

```
HMAC-SHA256(payload, secret)
```

### 客戶端實現

```swift
// AccountService.swift 新增

import CryptoKit

extension AccountService {

    /// 生成請求簽名
    private func generateSignature(
        method: String,
        endpoint: String,
        timestamp: Int64,
        body: Data?
    ) -> String {
        // 簽名內容：method + endpoint + timestamp + bodyHash
        let bodyHash = body.map { SHA256.hash(data: $0).hexString } ?? ""
        let payload = "\(method):\(endpoint):\(timestamp):\(bodyHash)"

        // 使用 device-specific secret（首次從伺服器獲取，存 Keychain）
        guard let secretData = getSigningSecret()?.data(using: .utf8) else {
            return ""
        }

        let key = SymmetricKey(data: secretData)
        let signature = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)

        return Data(signature).base64EncodedString()
    }

    /// 添加簽名標頭
    private func addSignatureHeaders(
        to request: inout URLRequest,
        body: Data?
    ) {
        let timestamp = Int64(Date().timeIntervalSince1970)
        let signature = generateSignature(
            method: request.httpMethod ?? "GET",
            endpoint: request.url?.path ?? "",
            timestamp: timestamp,
            body: body
        )

        request.setValue(String(timestamp), forHTTPHeaderField: "X-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-Signature")
        request.setValue(getDeviceId(), forHTTPHeaderField: "X-Device-ID")
    }
}

extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
```

### 後端驗證

```typescript
// 後端驗證邏輯
function verifySignature(req: Request): boolean {
  const timestamp = parseInt(req.headers['x-timestamp']);
  const signature = req.headers['x-signature'];
  const deviceId = req.headers['x-device-id'];

  // 1. 檢查時間戳（防重放攻擊，5分鐘窗口）
  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - timestamp) > 300) {
    return false;
  }

  // 2. 檢查 nonce（防重放）
  if (await redis.exists(`nonce:${signature}`)) {
    return false;
  }
  await redis.setex(`nonce:${signature}`, 600, '1');

  // 3. 驗證簽名
  const secret = await getDeviceSecret(deviceId);
  const payload = `${req.method}:${req.path}:${timestamp}:${bodyHash}`;
  const expectedSignature = hmacSha256(payload, secret);

  return timingSafeEqual(signature, expectedSignature);
}
```

### Device Secret 流程

```
1. 用戶首次登入成功
2. 伺服器生成 device_secret，關聯 (user_id, device_id)
3. 返回給客戶端，存入 Keychain
4. 後續敏感請求攜帶簽名
5. 用戶登出時，伺服器可選擇撤銷該 device_secret
```

---

## 3. Anomaly Monitoring（異常監控）

### 監控指標

```yaml
# 即時警報
high_frequency_requests:
  threshold: 50 req/min from single user
  action: temporary_block + alert

unusual_credit_consumption:
  threshold: >10 credits in 5 minutes
  action: alert + review

failed_auth_attempts:
  threshold: 10 failures/hour per IP
  action: captcha_required + alert

geographic_anomaly:
  condition: login from new country within 1 hour
  action: email_notification + optional_2fa
```

### 日誌結構

```json
{
  "timestamp": "2026-01-08T10:30:00Z",
  "event": "nano_banana_process",
  "user_id": "uuid",
  "device_id": "device-uuid",
  "ip": "192.168.1.1",
  "geo": { "country": "TW", "city": "Taipei" },
  "credits_used": 2,
  "credits_remaining": 48,
  "resolution": "2048",
  "processing_time_ms": 3500,
  "signature_valid": true
}
```

### 告警整合

- **Slack/Discord**: 即時警報
- **Email**: 每日摘要報告
- **Dashboard**: Grafana 視覺化

---

## 4. Refresh Token Rotation（令牌輪換）

### 當前問題

Refresh token 長期有效，若洩漏風險高。

### 改進方案：Rotation + Family Detection

```
每次使用 refresh_token：
1. 驗證 token 有效
2. 生成新的 access_token + 新的 refresh_token
3. 舊 refresh_token 立即失效
4. 記錄 token family（追蹤同一登入 session 的所有 token）
```

### Token Family 機制

```typescript
interface TokenFamily {
  family_id: string;      // 同一登入 session 的標識
  user_id: string;
  device_id: string;
  current_token: string;  // 當前有效的 refresh_token
  created_at: Date;
  last_used_at: Date;
  revoked: boolean;
}

// 偵測重放攻擊
async function handleRefresh(refreshToken: string) {
  const family = await getTokenFamily(refreshToken);

  if (family.current_token !== refreshToken) {
    // 舊 token 被重用！可能是攻擊
    // 撤銷整個 family，強制重新登入
    await revokeTokenFamily(family.family_id);
    throw new SecurityError('Token replay detected');
  }

  // 正常輪換
  const newTokens = generateTokens();
  await updateTokenFamily(family.family_id, newTokens.refreshToken);

  return newTokens;
}
```

### 客戶端更新

```swift
// AccountService.swift 修改 refreshAccessToken

func refreshAccessToken() async throws {
    guard let refresh = refreshToken else {
        throw AccountError.unauthorized
    }

    let body = ["refresh_token": refresh]
    let response: APIResponse<TokenResponse> = try await post(
        endpoint: "/auth/refresh",
        body: body,
        authenticated: false
    )

    guard let tokens = response.data else {
        throw AccountError.unauthorized
    }

    // 更新兩個 token（輪換機制）
    accessToken = tokens.accessToken
    refreshToken = tokens.refreshToken  // 新增：更新 refresh token
}
```

---

## 5. 實施優先級

| 優先級 | 措施 | 複雜度 | 影響 |
|--------|------|--------|------|
| 🔴 P0 | Rate Limiting | 低 | 防止濫用的基礎 |
| 🔴 P0 | Refresh Token Rotation | 中 | 降低 token 洩漏風險 |
| 🟡 P1 | Anomaly Monitoring | 中 | 偵測異常行為 |
| 🟢 P2 | Request Signing | 高 | 進階防護，可延後 |

---

## 6. 客戶端需要的變更

### 必須（P0）

1. **更新 `refreshAccessToken`** - 支援 token rotation，保存新的 refresh token

### 建議（P1-P2）

2. **新增 Device ID 管理** - 生成並持久化設備標識
3. **新增簽名模組** - 對敏感請求簽名（如果啟用）
4. **處理新的錯誤碼** - 429 Too Many Requests、403 Security Block

### 新增錯誤處理

```swift
enum AccountError: Error {
    // 現有...
    case rateLimited(retryAfter: Int)
    case securityBlock(reason: String)
    case tokenReplayDetected
}
```

---

## 7. 後端 API 變更摘要

### 新增標頭

```http
# 請求
X-Device-ID: <device-uuid>
X-Timestamp: <unix-timestamp>
X-Signature: <hmac-signature>  # 僅敏感操作

# 回應
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1704700800
```

### 新增端點

```
POST /auth/device/register  # 註冊設備，獲取簽名密鑰
DELETE /auth/device/{id}    # 撤銷設備授權
GET /user/devices           # 列出已授權設備
```

### 修改端點

```
POST /auth/refresh
- 回應現在包含新的 refresh_token
- 舊 refresh_token 立即失效
```
