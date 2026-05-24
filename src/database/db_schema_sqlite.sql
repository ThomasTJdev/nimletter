-- SQLite does not support SET TIME ZONE
-- SET TIME ZONE 'UTC';

-- SQLite does not support CREATE EXTENSION
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS mails (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  name                TEXT NOT NULL,
  identifier          TEXT NOT NULL UNIQUE,  -- Unique identifier for the mail, e.g. first-login
  send_once           BOOLEAN DEFAULT 1, -- Send only once to each user
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  contentHTML         TEXT,           -- Content of the mail
  contentEditor       TEXT,           -- The content from the editor, emailbuilder = JSON, maily.to = Markdown
  editorType          TEXT DEFAULT 'emailbuilder', -- html, emailbuilder, etc.
  subject             TEXT,           -- Subject of the mail
  tags                TEXT,           -- Array of tags associated with the mail (SQLite does not support arrays)
  category            TEXT,           -- Category of the mail (e.g., promotional, informational)
  uuid                TEXT NOT NULL DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-' || '4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', abs(random()) % 4 + 1, 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6))))  -- Unique identifier
);


-- Table for flows (campaigns or automated sequences)
CREATE TABLE IF NOT EXISTS flows (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  name                TEXT NOT NULL,  -- Name of the flow
  description         TEXT,           -- Description of the flow
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Table for flow steps (sequence and details for each step in the flow)
CREATE TABLE IF NOT EXISTS flow_steps (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  flow_id             INTEGER NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
  mail_id             INTEGER NOT NULL REFERENCES mails(id) ON DELETE CASCADE,
  step_number         INTEGER NOT NULL,  -- Sequence of steps in the flow
  trigger_type        TEXT DEFAULT 'delay', -- open, linkclick, delay, etc.
  delay_minutes       INTEGER NOT NULL DEFAULT 0, -- Delay from the previous step
  name                TEXT NOT NULL, -- Name of the step
  subject             TEXT NOT NULL, -- Email subject for this step
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Table for lists (grouping contacts for sending emails)
CREATE TABLE IF NOT EXISTS lists (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  name                TEXT NOT NULL,    -- Name of the list
  identifier          TEXT NOT NULL UNIQUE,  -- Unique identifier, e.g. welcome-list
  flow_ids            TEXT,            -- Flows associated with the list (SQLite does not support arrays)
  description         TEXT,             -- Description of the list
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  uuid                TEXT NOT NULL DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-' || '4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', abs(random()) % 4 + 1, 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6))))  -- Unique identifier
);

-- Default list
INSERT INTO lists (name, identifier, description) VALUES ('Default List', 'default', 'Default list for new users');

-- Table for contacts
CREATE TABLE IF NOT EXISTS contacts (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  name                TEXT,
  email               TEXT UNIQUE NOT NULL,
  status              TEXT DEFAULT 'enabled',  -- enabled, disabled, etc.
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  requires_double_opt_in BOOLEAN DEFAULT 1,  -- Flag for double opt-in status
  double_opt_in_sent  BOOLEAN DEFAULT 0,  -- Has initial double opt-in email been sent?
  double_opt_in       BOOLEAN DEFAULT 0,  -- Flag for double opt-in status
  double_opt_in_data  TEXT, -- IP address, timestamp, etc.
  pending_lists       TEXT, -- Pending lists to be signed up to until double_opt_in is complete (SQLite does not support arrays)
  bounced_at          DATETIME, -- Timestamp when the email bounced
  complained_at       DATETIME, -- Timestamp when the email was marked as spam
  meta                TEXT,     -- !! CRITICAL - Additional metadata for the user (SQLite does not support JSONB)
  uuid                TEXT NOT NULL DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-' || '4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', abs(random()) % 4 + 1, 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6))))
);

-- Table for subscriptions (contacts signing up for lists)
CREATE TABLE IF NOT EXISTS subscriptions (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id             INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  list_id             INTEGER NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
  subscribed_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (user_id, list_id)
);

-- Table for pending emails (emails to be sent)
CREATE TABLE IF NOT EXISTS pending_emails (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id             INTEGER NOT NULL REFERENCES contacts(id),
  list_id             INTEGER NULL REFERENCES lists(id),
  flow_id             INTEGER NULL REFERENCES flows(id), -- NULL for manual sends
  flow_step_id        INTEGER NULL REFERENCES flow_steps(id), -- Tied to a specific flow step
  mail_id             INTEGER NULL REFERENCES mails(id),
  trigger_type        TEXT,
  scheduled_for       DATETIME, -- NULL if send_immediately is TRUE, or NULL if we have another trigger
  status              TEXT DEFAULT 'pending', -- E.g., 'pending', 'scheduled', 'sent', 'failed'
  message_id          TEXT,  -- Store the message ID here
  sent_at             DATETIME,
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Table for email opens (tracking opens for analytics)
CREATE TABLE IF NOT EXISTS email_opens (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  pending_email_id    INTEGER NOT NULL REFERENCES pending_emails(id),
  user_id             INTEGER NOT NULL REFERENCES contacts(id),
  opened_at           DATETIME DEFAULT CURRENT_TIMESTAMP,
  device_info         TEXT,
  ip_address          TEXT,
  message_id          TEXT
);

-- Table for email clicks (tracking clicks for analytics)
CREATE TABLE IF NOT EXISTS email_clicks (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  pending_email_id    INTEGER NOT NULL REFERENCES pending_emails(id),
  user_id             INTEGER NOT NULL REFERENCES contacts(id),
  clicked_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  device_info         TEXT,
  ip_address          TEXT,
  link_url            TEXT NOT NULL,
  message_id          TEXT
);

CREATE TABLE IF NOT EXISTS email_bounces (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  pending_email_id    INTEGER NOT NULL REFERENCES pending_emails(id),
  user_id             INTEGER NOT NULL REFERENCES contacts(id),
  bounced_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  bounce_type         TEXT,
  bounce_subtype      TEXT,
  diagnostic_code     TEXT,
  status              TEXT,
  message_id          TEXT
);

CREATE TABLE IF NOT EXISTS email_complaints (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  pending_email_id    INTEGER NOT NULL REFERENCES pending_emails(id),
  user_id             INTEGER NOT NULL REFERENCES contacts(id),
  complained_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
  complaint_feedback  TEXT,
  message_id          TEXT
);

-- General settings
CREATE TABLE IF NOT EXISTS settings (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  page_name           TEXT NOT NULL,
  hostname            TEXT NOT NULL,
  optin_email         INTEGER NOT NULL REFERENCES mails(id),
  logo_url            TEXT,
  link_success        TEXT
);

INSERT INTO settings (page_name, hostname, optin_email) VALUES ('nimletter', 'https://nimletter.com', 1);

-- Table for smtp
CREATE TABLE IF NOT EXISTS smtp_settings (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  smtp_host           TEXT NOT NULL,
  smtp_port           INTEGER NOT NULL,
  smtp_user           TEXT NOT NULL,
  smtp_password       TEXT NOT NULL,
  smtp_fromemail      TEXT NOT NULL,
  smtp_fromname       TEXT NOT NULL,
  smtp_mailspersecond INTEGER DEFAULT 1,
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO smtp_settings (smtp_host, smtp_port, smtp_user, smtp_password, smtp_fromemail, smtp_fromname) VALUES ('email-smtp.eu-west-1.amazonaws.com', 465, 'AKIA', 'EXAMPLE', '', '');

-- Table for API keys
CREATE TABLE IF NOT EXISTS api_keys (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  key                 TEXT NOT NULL DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-' || '4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', abs(random()) % 4 + 1, 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  ident               TEXT NOT NULL DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-' || '4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', abs(random()) % 4 + 1, 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  name                TEXT,
  count               INTEGER DEFAULT 0,
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Table for webhooks
CREATE TABLE IF NOT EXISTS webhooks (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  name                TEXT,
  url                 TEXT NOT NULL,
  headers             TEXT, -- SQLite does not support JSON
  event               TEXT NOT NULL,  -- Event type (e.g., email_opened, email_clicked)
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- User table for authentication
CREATE TABLE IF NOT EXISTS users (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  email               TEXT NOT NULL UNIQUE,
  password            TEXT NOT NULL,
  salt                TEXT NOT NULL,
  yubikey_public      TEXT,
  yubikey_clientid    TEXT,
  twofa_app_secret    TEXT,
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);


-- Session table for storing user sessions
CREATE TABLE IF NOT EXISTS sessions (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id             INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token               TEXT NOT NULL,
  expires_at          DATETIME DEFAULT CURRENT_TIMESTAMP, -- - INTERVAL '7 days',
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_pending_emails_scheduled_for ON pending_emails (scheduled_for);
CREATE INDEX IF NOT EXISTS idx_email_opens_user_id ON email_opens (user_id);
CREATE INDEX IF NOT EXISTS idx_email_clicks_user_id ON email_clicks (user_id);