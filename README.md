# Skin Within Aesthetics — Seedscore Portal

A franchise performance management portal for Skin Within Aesthetics. Franchisees log in to complete their Monthly Business Review (MBR), receive an AI-generated Seed Score and personalised feedback, and head office can view all submissions in a live dashboard.

---

## Tech Stack

| Layer       | Technology |
|-------------|------------|
| Frontend    | Single-file HTML/CSS/JS |
| Auth        | Supabase Auth (email + password) |
| Database    | Supabase (PostgreSQL) |
| AI Feedback | Claude API (Anthropic) |
| Email       | FormSubmit |

---

## Setup Guide

### Step 1 — Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign in / create an account
2. Click **New project**, choose a name (e.g. `seedscore`), set a strong database password, and select your nearest region
3. Wait for the project to finish provisioning (~2 minutes)

---

### Step 2 — Run the Database Schema

1. In your Supabase project, go to **SQL Editor** → **New query**
2. Paste the entire contents of `supabase-schema.sql` and click **Run**
3. You should see "Success. No rows returned" — this means all tables, policies, and functions were created

---

### Step 3 — Add Your Supabase Keys to `index.html`

1. In Supabase, go to **Project Settings** → **API**
2. Copy your **Project URL** and **anon / public** key
3. Open `index.html` and find these two lines near the top of the `<script>` section:

```js
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

4. Replace the placeholder strings with your actual values

---

### Step 4 — Create User Accounts

#### Head Office Account

1. In Supabase, go to **Authentication** → **Users** → **Add user** → **Create new user**
2. Enter the head office email and a strong password, click **Create user**
3. Copy the UUID that appears next to the new user
4. Go to **Table Editor** → `profiles` table, find the row with that UUID, and set:
   - `full_name` → `Head Office`
   - `role` → `head_office`

#### Franchisee Accounts

For each franchisee:

1. **Authentication** → **Users** → **Add user** → **Create new user**
2. Enter their email and a password, click **Create user**
3. In the `profiles` table, find their row (auto-created by the database trigger) and fill in:
   - `full_name` → their full name (e.g. `Alice Morgan`)
   - `clinic_name` → their clinic/location (e.g. `Manchester North`)
   - `region` → their region (e.g. `North`, `South`, `East`, `West`)
   - `role` → `franchisee` (this is the default, so it may already be set)

##### Bulk update with SQL (optional)

After creating each user in the Auth dashboard, update their profile via SQL Editor:

```sql
update public.profiles
  set full_name   = 'Alice Morgan',
      clinic_name = 'Manchester North',
      region      = 'North'
  where id = '<paste-uuid-here>';
```

---

### Step 5 — Configure the Claude API (for AI Feedback)

The MBR form calls the Claude API to generate personalised feedback. To enable this:

1. Get an API key from [console.anthropic.com](https://console.anthropic.com)
2. In `index.html`, find the two `fetch("https://api.anthropic.com/v1/messages", ...)` calls inside `mbrSubmit()`
3. Add your API key to the `headers` object:

```js
headers: {
  "Content-Type": "application/json",
  "x-api-key": "sk-ant-YOUR_KEY_HERE",
  "anthropic-version": "2023-06-01",
  "anthropic-dangerous-direct-browser-access": "true"
}
```

> **Note:** For production, consider routing API calls through a Supabase Edge Function to keep your key server-side.

---

### Step 6 — Deploy

The portal is a single `index.html` file. You can host it anywhere:

- **Supabase Storage** — upload `index.html` to a public bucket and enable static hosting
- **Netlify / Vercel** — drag and drop the file, or connect this repo
- **GitHub Pages** — push to a `gh-pages` branch

---

## How It Works

### Login Flow

```
User enters email + password
        ↓
Supabase Auth verifies credentials
        ↓
App fetches user profile (role, name, clinic)
        ↓
role = 'head_office'  →  Head Office Dashboard
role = 'franchisee'   →  Franchisee Dashboard
```

### MBR Submission Flow

```
Franchisee completes 11-section form
        ↓
Score calculated client-side (0–100)
        ↓
Claude API generates personalised feedback + 3 priority actions
        ↓
Submission saved to Supabase (mbr_submissions table)
        ↓
Email notification sent via FormSubmit
        ↓
Results displayed to franchisee
```

### Head Office Dashboard

- Reads all franchisee profiles + their latest submission score from Supabase
- Shows live network stats: total franchisees, average score, passing/review counts
- Sortable, searchable, filterable table with score bars and trend indicators

### Franchisee Dashboard

- Shows their own submission history (score chart, history table)
- Network rank calculated dynamically against all current franchisees
- Scores persist across sessions — always reflect the latest saved submission

---

## Database Tables

| Table | Purpose |
|-------|---------|
| `profiles` | One row per user — name, clinic, region, role |
| `mbr_submissions` | One row per MBR submission — score, full form data, AI feedback, actions |

Row-level security (RLS) ensures franchisees can only read/write their own data. Head office can read all.

---

## FormSubmit Email

The portal sends MBR results to `bethany@skinwithinaesthetics.co.uk` via [FormSubmit](https://formsubmit.co).

To change the recipient, update this line in `index.html`:

```js
const FORMSUBMIT_EMAIL = 'bethany@skinwithinaesthetics.co.uk';
```

On first submission to a new email address, FormSubmit will send a one-time confirmation email — click the link to activate it.
