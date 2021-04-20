This document outlines best practices for the gDR team.

## Reporting issues
Issue reporting is done in JIRA in the [gDR project](https://jira.gene.com/jira/secure/RapidBoard.jspa?rapidView=15415&projectKey=GDR) using *JIRA tickets*. 

Every ticket should have the following fields filled: 
* `Title` – If relating to a front-end application, should begin with the relevant module of the application in format: `[module name]: <feature request>`. For example, in reporting new features or bugs for the gDRviz app dose response overview section, ticket should be named as: `[Dose Response Overview]: add ability to color by drug name`. Otherwise, the title should contain a succint description that will be understandable several months from now.
* `Epic` – should be set to the relevant epic that the change requires. For issues reported by users, this will likely be either `gDRviz`, `gDRin`, or `gDRsearch`. For developers, this will be the relevant package that requires a change.
* `Label` – should be set to the release that the ticket relates to. If the feature is relevant to the 1.0.0 release, the label should be set to: `1.0.0`.
* `Status` – If relevant for the current release, change status to `TODO`. Otherwise, leave as the default `Backlog`. 
* `Assignee` -- If the person who will work on the ticket is already known, assign appropriately. Otherwise, leave as the default `Unassigned`.

If a ticket is assigned to you, keep the ticket's status up-to-date. You are responsible for moving a ticket through the following stages: `TODO` -> `In Progress` -> `In code Review` -> `Code Review Approved`. `In code Review` means a PR has been created to resolve the ticket. `Code Review Approved` means the ticket branch has been merged into `master`.
NOTE: When a ticket to is moved to `Code Review Approved`, it will require that the `Fix Version` field be populated. Populate this with the package version containing your feature or fix.

If you have nothing to work on, select from any of the `Unassigned` tickets and assign to yourself. 

## JIRA ticket management
The [Kanban board](https://jira.gene.com/jira/secure/RapidBoard.jspa?rapidView=15415&projectKey=GDR&view=detail&selectedIssue=GDR-816&quickFilter=20363) will default to a filter containing the tickets relevant for the current release. The filter is looking for all tickets with a `label` equal to the current release `x.y.z`.
Tickets that are assigned to you are either awaiting your feedback or your work on the ticket itself. Once you have addressed the feedback or if you are not the appropriate person to complete the ticket, reassign to the correct person. 

## Branches and Environments (Deployment model)
Each package has the following 4 branches in github: 
* master
* dev
* tst
* prd 

Feature branches should be named after the ticket number. For example, for a JIRA ticket "GDR-800", the branch containing the change should also be called `GDR-800`.

Deployed changes should progress through these branches.
A `feature_branch` should be merged into `master`. Every night in GMT, all changes on `master` will be merged into `dev`, and the apps will be deployed off of the `dev` branch in the "dev" environment at: http://gdrviz-dev.kubnala.science.roche.com/ and friends. The person in GMT time who deploys to a given environment will also move all tickets to the appropriate status lane (i.e. from the `Code Review Approved` to `In Dev` status). The same workflow follows to move changes onto the `test` and `prd` environments. 
