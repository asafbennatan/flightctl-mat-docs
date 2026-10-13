---
status: proposed
---

# Issuance-based auto-approval window with unchanged certificate lifetime

EDM-4868 keeps the existing one-year default enrollment-certificate validity
and existing explicit expiration settings unchanged.
Each policy may optionally set `autoApprovalWindowDays`, measured from the
immutable server-owned CSR issuance time recorded when the certificate is
published.
A credential can remain valid for a year while its policies auto-approve only
during the first N days after issuance.

Short-lived enrollment certificates were rejected because they change PKI
defaults for every deployment and couple credential lifetime to policy intent.
A window measured from first use was rejected as ambiguous and gameable;
issuance time is durable and server-owned.
Window expiry means manual fallback, never revocation or rejection.
A window extending past the certificate's `NotAfter` does not extend
certificate validity, and reporting or retries never restart the window.
