# AWS IAM Cross-Account Access

## Overview
Organisations run workloads on AWS in environments split across multiple accounts. This is to isolate workloads, enforce security boundaries, and limit the blast radius of a potential breach. Managing access across accounts securely is one of the core challenges of cyber/ cloud security. 

This project implements a multi-account AWS architecture using IAM cross-account role assumption to demonstrate how a security engineer can securely access multiple accounts from a single identity. The engineer can access these accounts without adding long-lived credentials distributed across environments. Access is temporary, MFA-enforced, and fully logged.

The project includes five AWS accounts that are managed under AWS Organisations - a management account, security account, workload account, logging account, and dev account. Two IAM roles are deployed in each members account: a read-only SecurityAuditRole for routine reviews and an IncidentResponseRole with limited write access for active incident handling. CloudTrail is utilised across accounts with logs centralised in a integral S3 bucket in the dedicated logging account.

This project demonstrates enterprise AWS account architecture, IAM policy design, least privilege principles, temporary credential management, infrastructure as code with Terraform, and centralised audit logging. These are applicable to cloud security engineering and consulting roles.

---

## Architecture Diagram
```
┌─────────────────────────────────────────────────────────────────────────┐
│                          AWS ORGANIZATION                               │
│                                                                         │
│                    ┌────────────────────────┐                           │
│                    │   MANAGEMENT ACCOUNT   │                           │
│                    │                        │                           │
│                    │  ┌──────────────────┐  │                           │
│                    │  │  security-admin  │  │                           │
│                    │  │    IAM User      │  │                           │
│                    │  │    + MFA         │  │                           │
│                    │  └────────┬─────────┘  │                           │
│                    └───────────┼────────────┘                           │
│                                │                                        │
│                    sts:AssumeRole (+ ExternalId + MFA)                  │
│                                │                                        │
│          ┌─────────────────────┼─────────────────────┐                  │
│          │                     │                     │                  │
│          ▼                     ▼                     ▼                  │
│  ┌──────────────┐   ┌──────────────────┐   ┌──────────────┐             │
│  │   SECURITY   │   │    WORKLOAD      │   │     DEV      │             │
│  │   ACCOUNT    │   │    ACCOUNT       │   │   ACCOUNT    │             │
│  │              │   │                  │   │              │             │
│  │ - SecurityAu │   │ - SecurityAudit  │   │ - SecurityAu │             │
│  │   ditRole    │   │   Role           │   │   ditRole    │             │
│  │   (read only)│   │   (read only)    │   │  (read only) │             │
│  │              │   │                  │   │              │             │
│  │ - Incident   │   │ - Incident       │   │ - Incident   │             │
│  │   Response   │   │   Response       │   │   Response   │             │
│  │   Role       │   │   Role           │   │   Role       │             │
│  │ (limited     │   │ (limited write)  │   │ (limited     │             │
│  │  write)      │   │                  │   │  write)      │             │
│  └──────┬───────┘   └────────┬─────────┘   └──────┬───────┘             │
│         │                    │                    │                     │
│         │         CloudTrail logs                 │                     │
│         │         (all accounts)                  │                     │
│         └──────────────────┬──────────────────────┘                     │
│                            │                                            │
│                            ▼                                            │
│                  ┌───────────────────────┐                              │
│                  │    LOGGING ACCOUNT    │                              │
│                  │                       │                              │
│                  │  S3 Bucket            │                              │
│                  │  - Encrypted          │                              │
│                  │  - Versioned          │                              │
│                  │  - Public access off  │                              │
│                  │  - Tamper resistant   │                              │
│                  └───────────────────────┘                              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```
Role Assumption Flow:
  1. security-admin authenticates with password + MFA
  2. Calls sts:AssumeRole with ExternalId
  3. Trust policy on target role is evaluated
  4. Temporary credentials returned (expire in 1 hour)
  5. Engineer operates in target account
  6. All actions logged to CloudTrail → Logging Account

---

## Account Structure
Management Account -> Central control and houses the security-admin IAM user. No application resources deployed here.

Security Account -> Represents the security team's operational environment.

Workload Account -> Represents production application infrastructure.

Logging Account -> Dedicated logging archive. Receives CloudTrail logs from all accounts. Kept separate to maintain integrity if another account is compromised.

Dev Account -> Represents developing and testing environment. Kept isolated from production.

---

## Roles and Permissions
Two roles were deployed in each account via Terraform.

### SecurityAuditRole
A role configured to read-only for routine security reviews. Allows a security engineer to inspect configurations, review IAM settings, and check resource states.

**Permissions attached:** 
- 'SecurityAudit' (AWS managed) - read access to security-relevant configurations across all AWS services.
- 'ViewOnlyAccess' (AWS managed) - read access to see what resources exist across the account.

**Trust policy conditions:**
- Principal must be from management account
- ExternalId must match a pre-shared secret value
- MFA must be present on the assuming identity

### IncidentResponseRole
A role used during active security incidents with limited write access. Allows security engineers contain threats by isolating resources via security group modification or stopping compromised instances.

**Permissions:**
- Read access: EC2 describe actions, IAM read, CloudTrail, CloudWatch logs
- Write access: Stop EC2 instances, modify security group rules

**Deliberately excluded:**
- No ability to delete resources
- No ability to create users or roles
- No access to S3, RDS, or other data stores
- No ability to disable logging

**Trust policy conditions:**
- Same as SecurityAuditRole - management account principal, ExternalId, and MFA required

---

## Security Design Decisions

### Why Role Assumption Instead of Long-Lived Credentials?
If long-lived IAM access keys are ever leaked - through config files, a compromised developer machine, or an internal breach - an attacker would have permanent access until someone manually rotates them. In practice, keys often aren't rotated for months or years. 

Role assumption temporary credentials automatically expire after a maximum of one hour. A leaked session token is only useful for this short window. Furthermore, there are no secrets to distribute or manage - the assuming identity just needs permission to call AssumeRole.

## Why MFA is Required 
The trust policies on every role include a condition that requires MFA to be present on the assuming identity. This means an attacker cannot assume any role without also accessing the MFA device. Credentials alone are not enough.

### Why ExternalId is Used
ExternalId condition is used to protect against the confused deputy problem. Without it, any third party service that has been granted permission to assume roles in your account could be tricked by an attacker into assuming your roles on their behalf. When ExternalId condition is added to your trust policy, the assumption only works if a secret value is included, which is a secret that is set and only shared with trusted parties. 

### Why Least Privilege was Applied 
Each role has only the permissions it needs for its specific purpose. The 'SecurityAuditRole' has no write permissions. The 'IncidentResponseRole' has limited write for specific EC2 actions relevant to incident containment.

This limits the blast radius of a compromised role due to the bounded permissions. This lessens the impact of attacks to be recoverable. 

### Why Logs Are in a Separate Account
CloudTrail logs are shipped to a dedicated S3 bucket in the logging account. This means that even if the workload or security account is fully compromised, the attacker cannot access or delete logs - that would require access to completely separate credentials. Tamper-resistant logging is a core requirement in security architecture and is mandated by compliance frameworks like SOC 2, PCI DSS, and ISO 27001.

---

## How Role Assumption Works
1.  The engineer authenticates to the management account as the 'security-admin' IAM user with their password and MFA code.

2.  They call the AWS STS AssumeRole API, providing:
    - The ARN of the role they want to assume
    - Their MFA serial number and current token code
    - The ExternalId secret
3.  AWS STS checks the trust policy on the target role, checking:
    - Is the request coming from the management account?
    - Was MFA used?
    - Does the ExternalId match

