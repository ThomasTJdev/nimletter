SET TIME ZONE 'UTC';

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS mails (
  id                  SERIAL PRIMARY KEY,
  name                TEXT NOT NULL,
  identifier          TEXT NOT NULL UNIQUE,  -- Unique identifier for the mail, e.g. first-login
  send_once           BOOLEAN DEFAULT TRUE, -- Send only once to each user
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  contentHTML         TEXT,           -- Content of the mail
  contentEditor       TEXT,           -- The content from the editor, emailbuilder = JSON, maily.to = Markdown
  editorType          TEXT DEFAULT 'emailbuilder', -- html, emailbuilder, etc.
  subject             TEXT,           -- Subject of the mail
  tags                TEXT[],         -- Array of tags associated with the mail
  category            TEXT,           -- Category of the mail (e.g., promotional, informational)
  uuid                UUID NOT NULL DEFAULT uuid_generate_v4()
);


-- Table for flows (campaigns or automated sequences)
CREATE TABLE IF NOT EXISTS flows (
  id                  SERIAL PRIMARY KEY,
  name                TEXT NOT NULL,  -- Name of the flow
  description         TEXT,           -- Description of the flow
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  is_deleted          TIMESTAMP DEFAULT NULL
);

-- Table for flow steps (sequence and details for each step in the flow)
CREATE TABLE IF NOT EXISTS flow_steps (
  id                  SERIAL PRIMARY KEY,
  flow_id             INT NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
  mail_id             INT NOT NULL REFERENCES mails(id) ON DELETE CASCADE,
  step_number         INT NOT NULL,  -- Sequence of steps in the flow
  trigger_type        TEXT DEFAULT 'delay', -- open, linkclick, delay, etc.
  delay_minutes       INT NOT NULL DEFAULT 0, -- Delay from the previous step
  scheduled_time      TIME DEFAULT NULL, -- Specific time to schedule the email (in GMT0)
  name                TEXT NOT NULL, -- Name of the step
  subject             TEXT NOT NULL, -- Email subject for this step
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for lists (grouping contacts for sending emails)
CREATE TABLE IF NOT EXISTS lists (
  id                  SERIAL PRIMARY KEY,
  name                TEXT NOT NULL,    -- Name of the list
  identifier          TEXT NOT NULL UNIQUE,  -- Unique identifier, e.g. welcome-list
  flow_ids            INT[],            -- Flows associated with the list
  description         TEXT,             -- Description of the list
  require_optin       BOOLEAN DEFAULT TRUE,  -- Flag for double opt-in status
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  uuid                UUID NOT NULL DEFAULT uuid_generate_v4(),
  is_deleted          TIMESTAMP DEFAULT NULL
);
-- Default list
INSERT INTO lists (name, identifier, description) VALUES ('Default List', 'default', 'Default list for new users') ON CONFLICT DO NOTHING;

-- Table for contacts
CREATE TABLE IF NOT EXISTS contacts (
  id                  SERIAL PRIMARY KEY,
  name                VARCHAR(255),
  email               VARCHAR(255) UNIQUE NOT NULL,
  status              TEXT DEFAULT 'enabled',  -- enabled, disabled, etc.
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  requires_double_opt_in BOOLEAN DEFAULT TRUE,  -- Flag for double opt-in status
  double_opt_in_sent  BOOLEAN DEFAULT FALSE,  -- Has initial double opt-in email been sent
  double_opt_in       BOOLEAN DEFAULT FALSE,  -- Flag for double opt-in status
  double_opt_in_data  TEXT, -- IP address, timestamp, etc.
  pending_lists       INT[], -- Pending lists to be signed up to until double_opt_in is complete
  bounced_at          TIMESTAMP, -- Timestamp when the email bounced
  complained_at       TIMESTAMP, -- Timestamp when the email was marked as spam
  meta                JSONB,          -- Additional metadata for the user
  uuid                UUID NOT NULL DEFAULT uuid_generate_v4()
);

-- Table for subscriptions (contacts signing up for lists)
CREATE TABLE IF NOT EXISTS subscriptions (
  id                  SERIAL PRIMARY KEY,
  user_id             INT NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  list_id             INT NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
  subscribed_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (user_id, list_id)
);

-- Table for pending emails (emails to be sent)
CREATE TABLE IF NOT EXISTS pending_emails (
  id                  SERIAL PRIMARY KEY,
  user_id             INT NOT NULL REFERENCES contacts(id),
  list_id             INT NULL REFERENCES lists(id),
  flow_id             INT NULL REFERENCES flows(id), -- NULL for manual sends
  flow_step_id        INT NULL REFERENCES flow_steps(id), -- Tied to a specific flow step
  mail_id             INT NULL REFERENCES mails(id),
  trigger_type        TEXT,
  scheduled_for       TIMESTAMP, -- NULL if send_immediately is TRUE, or NULL if we have another trigger
  status              TEXT DEFAULT 'pending', -- E.g., 'pending', 'scheduled', 'sent', 'failed'
  message_id          TEXT,  -- Store the message ID here
  sent_at             TIMESTAMP,
  manual_html         TEXT,  -- Manually created HTML content
  manual_subject      TEXT,  -- Manually created subject
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  uuid                UUID NOT NULL DEFAULT uuid_generate_v4()
);

-- Table for email opens (tracking opens for analytics)
CREATE TABLE IF NOT EXISTS email_opens (
  id                  SERIAL PRIMARY KEY,
  pending_email_id    INT NOT NULL REFERENCES pending_emails(id),
  user_id             INT NOT NULL REFERENCES contacts(id),
  opened_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  device_info         TEXT,
  ip_address          TEXT,
  message_id          TEXT
);

-- Table for email clicks (tracking clicks for analytics)
CREATE TABLE IF NOT EXISTS email_clicks (
  id                  SERIAL PRIMARY KEY,
  pending_email_id    INT NOT NULL REFERENCES pending_emails(id),
  user_id             INT NOT NULL REFERENCES contacts(id),
  clicked_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  device_info         TEXT,
  ip_address          TEXT,
  link_url            TEXT NOT NULL,
  message_id          TEXT
);

CREATE TABLE IF NOT EXISTS email_bounces (
  id                  SERIAL PRIMARY KEY,
  pending_email_id    INT NOT NULL REFERENCES pending_emails(id),
  user_id             INT NOT NULL REFERENCES contacts(id),
  bounced_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  bounce_type         TEXT,
  bounce_subtype      TEXT,
  diagnostic_code     TEXT,
  status              TEXT,
  message_id          TEXT
);

CREATE TABLE IF NOT EXISTS email_complaints (
  id                  SERIAL PRIMARY KEY,
  pending_email_id    INT NOT NULL REFERENCES pending_emails(id),
  user_id             INT NOT NULL REFERENCES contacts(id),
  complained_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  complaint_feedback  TEXT,
  message_id          TEXT
);


-- General settings
CREATE TABLE IF NOT EXISTS settings (
  id                  SERIAL PRIMARY KEY,
  page_name           TEXT NOT NULL,
  hostname            TEXT NOT NULL,
  optin_email         INT NOT NULL REFERENCES mails(id),
  logo_url            TEXT,
  link_success        TEXT,
);


-- Table for smtp
CREATE TABLE IF NOT EXISTS smtp_settings (
  id                  SERIAL PRIMARY KEY,
  smtp_host           TEXT NOT NULL,
  smtp_port           INT NOT NULL,
  smtp_user           TEXT NOT NULL,
  smtp_password       TEXT NOT NULL,
  smtp_fromemail      TEXT NOT NULL,
  smtp_fromname       TEXT NOT NULL,
  smtp_mailspersecond INT DEFAULT 1,
  smtp_use_aws_ses    BOOLEAN DEFAULT FALSE,
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO smtp_settings (smtp_host, smtp_port, smtp_user, smtp_password, smtp_fromemail, smtp_fromname)
SELECT 'email-smtp.eu-west-1.amazonaws.com', 465, 'AKIA', 'EXAMPLE', '', ''
WHERE NOT EXISTS (SELECT 1 FROM smtp_settings);

-- Table for API keys
CREATE TABLE IF NOT EXISTS api_keys (
  id                  SERIAL PRIMARY KEY,
  key                 UUID NOT NULL DEFAULT uuid_generate_v4(),
  ident               UUID NOT NULL DEFAULT uuid_generate_v4(),
  name                TEXT,
  count               INT DEFAULT 0,
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for webhooks
CREATE TABLE IF NOT EXISTS webhooks (
  id                  SERIAL PRIMARY KEY,
  name                TEXT,
  url                 TEXT NOT NULL,
  headers             JSON,
  event               TEXT NOT NULL,  -- Event type (e.g., email_opened, email_clicked)
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User table for authentication
CREATE TABLE IF NOT EXISTS users (
  id                  SERIAL PRIMARY KEY,
  email               TEXT NOT NULL UNIQUE,
  password            TEXT NOT NULL,
  salt                TEXT NOT NULL,
  yubikey_public      TEXT,
  yubikey_clientid    TEXT,
  twofa_app_secret    TEXT,
  rank                TEXT DEFAULT 'user',
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- Session table for storing user sessions
CREATE TABLE IF NOT EXISTS sessions (
  id                  SERIAL PRIMARY KEY,
  user_id             INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token               TEXT NOT NULL,
  expires_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- - INTERVAL '7 days',
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for efficient querying
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_pending_emails_scheduled_for ON pending_emails (scheduled_for);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_pending_emails_flowstep_include ON pending_emails (flow_step_id) INCLUDE (user_id, status, sent_at, id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_email_opens_user_id ON email_opens (user_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_email_clicks_user_id ON email_clicks (user_id);



-- Changelog
ALTER TABLE flows ADD COLUMN IF NOT EXISTS is_deleted TIMESTAMP DEFAULT NULL;
ALTER TABLE lists ADD COLUMN IF NOT EXISTS is_deleted TIMESTAMP DEFAULT NULL;
ALTER TABLE smtp_settings ADD COLUMN IF NOT EXISTS smtp_use_aws_ses BOOLEAN DEFAULT FALSE;