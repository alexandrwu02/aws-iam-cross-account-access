# AWS IAM Cross-Account Access

## Overview
Organisations run workloads on AWS in environments split across multiple accounts. This is to isolate workloads, enforce security boundaries, and limit the blast radius of a potential breach. Managing access across accounts securely is one of the core challenges of cyber/ cloud security. 

This project implements a multi-account AWS architecture using IAM cross-account role assumption to demonstrate how a security engineer can securely access multiple accounts from a single identity. The engineer can access these accounts without adding long-lived credentials distributed across environments. Access is temporary, MFA-enforced, and fully logged.

The project includes five AWS accounts that are managed under AWS Organisations - a management account, security account, workload account, logging account, and dev account. Two IAM roles are deployed in each members account: a read-only SecurityAuditRole for routine reviews and an IncidentResponseRole with limited write access for active incident handling. CloudTrail is utilised across accounts with logs centralised in a integral S3 bucket in the dedicated logging account.

This project demonstrates enterprise AWS account architecture, IAM policy design, least privilege principles, temporary credential management, infrastructure as code with Terraform, and centralised audit logging. These are applicable to cloud security engineering and consulting roles.

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

Role Assumption Flow:
  1. security-admin authenticates with password + MFA
  2. Calls sts:AssumeRole with ExternalId
  3. Trust policy on target role is evaluated
  4. Temporary credentials returned (expire in 1 hour)
  5. Engineer operates in target account
  6. All actions logged to CloudTrail → Logging Account

```




