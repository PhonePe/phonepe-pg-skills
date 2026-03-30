# PhonePe Payment Gateway Skills

This repository contains **Agent Skills** for integrating with PhonePe Payment Gateway APIs. These skills enable GitHub Copilot CLI, Copilot coding agent, and VS Code to assist you in implementing PhonePe PG integration with proper authentication, payment flows, and error handling.

---

## 📋 Table of Contents

- [About These Skills](#about-these-skills)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Available Skills](#available-skills)
- [Usage Examples](#usage-examples)
- [Environment Configuration](#environment-configuration)
- [Troubleshooting](#troubleshooting)

---

## 🎯 About These Skills

This skill collection provides AI-powered assistance for:

- ✅ **Authentication** - OAuth token generation and management for PhonePe PG APIs
- ✅ **Standard Checkout** - One-time payment integration
- ✅ **Check Payment Status** - Query order state (COMPLETED, PENDING, FAILED) with full payment details
- ✅ **Refunds** - Processing full or partial refunds

These skills follow PhonePe's official API specifications and handle common integration scenarios, error handling, and best practices.

---

## 📦 Prerequisites

Before using these skills, ensure you have:

1. **PhonePe Payment Gateway Account**
   - Merchant ID
   - Client ID and Client Secret
   - API credentials (sandbox and/or production)

2. **GitHub Copilot CLI** (or one of the supported tools)
   - Install: `brew install copilot-cli` or [other installation methods](https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-cli)
   - Active Copilot subscription

3. **Development Environment**
   - Bash shell (for setup script)
   - Programming language of your choice (Node.js, Python, Java, etc.)
   - HTTPS-enabled callback URL for payment redirects

---

## 🚀 Setup Instructions

### Quick Setup (One Command)

Install directly with a single command:

```bash
# Using wget
wget -qO- https://raw.githubusercontent.com/PhonePe/phonepe-pg-skills/main/setup.sh | bash

# Or using curl
curl -fsSL https://raw.githubusercontent.com/PhonePe/phonepe-pg-skills/main/setup.sh | bash
```

The script will:
- Check prerequisites (Git, GitHub Copilot CLI)
- Clone the repository automatically
- Guide you through setup for new or existing projects
- Create .env.template with configuration
- Update .gitignore for security

### Alternative: Clone and Run

If you prefer to clone first:

```bash
git clone https://github.com/PhonePe/phonepe-pg-skills.git
cd phonepe-pg-skills
./setup.sh
```

### Manual Setup

<details>
<summary>Click to expand manual setup instructions</summary>

### Step 1: Clone or Use This Repository

If you're starting a new project:

```bash
# Clone this repository
git clone https://github.com/PhonePe/phonepe-pg-skills.git
cd phonepe_pg_skills

# Start GitHub Copilot CLI in this directory
copilot
```

If adding to an existing project:

```bash
# Copy the skills directory to your project
cp -r .github/skills /path/to/your/project/.github/

# Navigate to your project
cd /path/to/your/project

# Start GitHub Copilot CLI
copilot
```

</details>

---

## 💡 Usage Examples

### Example 1: Accept Your First Payment Online

Start Copilot CLI in your project directory:

```bash
copilot
```

Then prompt Copilot:

```
Help me integrate PhonePe payment gateway. Create a payment order for ₹100 with order ID "ORDER123" and redirect URL "https://mysite.com/callback"
```

Copilot will:
1. Fetch authentication token using your credentials
2. Build the correct API payload
3. Generate code to make the API call
4. Parse and return the payment URL

---

### Example 2: Implement Complete Payment Flow

```
Create a Node.js function to initiate a PhonePe payment with the following:
- Order ID: Generate unique ID
- Amount: ₹500
- Enable only UPI and credit cards
- Add metadata with user ID
- Handle success and error responses
```

---

### Example 3: Process a Refund

```
Help me refund order "ORDER123" for ₹100. Create a function that handles the refund API call with proper error handling.
```

---

### Example 4: Debug Integration Issues

```
I'm getting "AUTHORIZATION_FAILED" error when calling PhonePe checkout API. Help me debug this.
```

Copilot will:
- Check your authentication flow
- Verify token generation logic
- Suggest fixes based on error codes

---

## ⚙️ Environment Configuration

### Sandbox vs Production

**Sandbox (Testing):**
```bash
PHONEPE_ENV=sandbox
# Uses: https://api-preprod.phonepe.com/apis/pg-sandbox/
```

**Production:**
```bash
PHONEPE_ENV=production
# Uses: https://api.phonepe.com/apis/pg/
```

### Configuration File Example

Create `config/phonepe.js` (Node.js example):

```javascript
module.exports = {
  environment: process.env.PHONEPE_ENV || 'sandbox',
  clientId: process.env.PHONEPE_CLIENT_ID,
  clientSecret: process.env.PHONEPE_CLIENT_SECRET,
  clientVersion: process.env.PHONEPE_CLIENT_VERSION,
  merchantId: process.env.PHONEPE_MERCHANT_ID,
  redirectUrl: process.env.PHONEPE_REDIRECT_URL,
};
```

---

## 🔧 Troubleshooting

### Skills Not Loading

**Problem:** `/skills list` returns empty

**Solutions:**
1. Check file structure: `.github/skills/phonepe-pg-skill/SKILL.md` must exist
2. Verify SKILL.md frontmatter has lowercase `name` field
3. Run `/skills reload`
4. Restart Copilot CLI

---

### Authentication Errors

**Problem:** Getting `AUTHORIZATION_FAILED` or 401 errors

**Solutions:**
1. Verify credentials are correct
2. Check if token is expired (tokens last ~7 days)
3. Ensure `O-Bearer` prefix in Authorization header
4. Confirm environment (sandbox vs production) matches credentials

---

### Invalid Transaction ID

**Problem:** Error `INVALID_TRANSACTION_ID` or 417 status

**Solutions:**
1. Ensure `merchantOrderId` is unique per transaction
2. Check that Order ID only contains alphanumeric, `_`, and `-`
3. Maximum length is 63 characters

---

## 📚 Additional Resources

- [PhonePe PG Official Documentation](https://developer.phonepe.com/)
- [GitHub Copilot CLI Documentation](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli)
- [Agent Skills Standard](https://github.com/agentskills/agentskills)

---

## Contributing

Contributions to PG Java SDK are welcome! Here's how you can contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure your code follows the project's coding standards and includes appropriate tests.

---

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

```
Copyright 2026 PhonePe Private Limited

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
