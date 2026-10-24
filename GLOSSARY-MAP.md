# Flight Control Glossary Map

Flight Control has several bounded domain contexts. Each context owns its own glossary; use this map to find the relevant language before working across contexts.

## Contexts

- [Image management](./glossaries/image-management/GLOSSARY.md): identifies images and describes the outcomes of applying deltas.
- [Fleet management](./glossaries/fleet-management/GLOSSARY.md): describes how devices become owned by fleets and what ownership establishes.
- [Authentication](./glossaries/authentication/GLOSSARY.md): describes user-facing identity-provider configuration.
- [Enrollment](./glossaries/enrollment/GLOSSARY.md): describes enrollment credentials, Enrollment Requests, TPM proof, revocation, device admission, and credential provenance.
- [Automatic approval](./glossaries/automatic-approval/GLOSSARY.md): describes the policies that automatically approve Enrollment Requests.

## Relationships

- **Enrollment → Automatic approval**: Enrollment owns the Enrollment Request, its server-verified trust state, and committed Device enrollment provenance; Automatic approval evaluates those facts and commits an admission.
- **Authentication → Enrollment**: Authentication describes user identity providers; enrollment certificates authenticate devices independently of those providers.
- **Enrollment → Fleet management**: Enrollment commits device admission; an admitted device joins a fleet when its labels match a fleet's selector.
- **Fleet management → Image management**: A fleet join can change a device's desired target digest, creating a need for an OCI image delta.
- **Image management**: Otherwise independent of enrollment and automatic approval.
