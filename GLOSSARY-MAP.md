# Flight Control Glossary Map

Flight Control has several bounded domain contexts. Each context owns its own glossary; use this map to find the relevant language before working across contexts.

## Contexts

- [Image management](./glossaries/image-management/GLOSSARY.md): identifies images and describes the outcomes of applying deltas.
- [Authentication](./glossaries/authentication/GLOSSARY.md): describes user-facing identity-provider configuration.
- [Enrollment](./glossaries/enrollment/GLOSSARY.md): describes enrollment credentials, Enrollment Requests, TPM proof, revocation, and device admission.
- [Automatic approval](./glossaries/automatic-approval/GLOSSARY.md): describes the policies that automatically approve Enrollment Requests.

## Relationships

- **Enrollment → Automatic approval**: Enrollment owns the Enrollment Request and its server-verified trust state; Automatic approval evaluates those facts and commits an admission.
- **Authentication → Enrollment**: Authentication describes user identity providers; enrollment certificates authenticate devices independently of those providers.
- **Image management**: Independent of enrollment and automatic approval.
