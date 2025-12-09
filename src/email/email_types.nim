

type
  SmtpData* = tuple[
    smtpHost: string,
    smtpPort: string,
    smtpUser: string,
    smtpPass: string,
    smtpFromEmail: string,
    smtpFromName: string,
    smtpMailspersecond: int,
    smtpUseAwsSes: bool
  ]
