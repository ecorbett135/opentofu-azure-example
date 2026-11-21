# OpenTofu on Azure

This example manages one Azure resource group. A manually triggered GitHub Actions workflow generates a plan, then optionally hands the saved plan to a separate apply job. OpenTofu stores state in an existing Azure Blob container.

## How it works

- **Plan** checks out the selected commit, installs the pinned OpenTofu version, and initializes the Azure backend with the committed provider lock file. It checks formatting and validates the configuration before printing the proposed changes.
- **Apply** runs only when requested and after plan succeeds. It checks out the same commit, initializes the same backend, and applies the saved binary plan after any configured environment approval. It does not generate a second plan.
- **State and authentication** are shared across runs. Azure Blob Storage holds the state and provides locking. Each job exchanges a GitHub OIDC token for Azure access, so no Azure client secret is required.
- **Plan artifacts** are uploaded only for deployment runs and expire after one day. Saved plans can include state and input values. This demo uses nonsecret inputs. Revisit artifact access before adapting it to infrastructure with sensitive values.

## Prerequisites

You need a GitHub repository with Actions enabled, an Azure sandbox subscription, and permission to configure Entra workload identity and Azure role assignments. The workflow uses GitHub-hosted runners, which must be able to reach the state storage account.

## Set up

1. Copy this directory into a GitHub repository, including the dotfiles and provider lock file.
2. Use an existing Azure storage account and blob container for state. Give the example its own container so its state stays separate from other deployments. The workflow uses the blob key `example.tfstate`.
3. Create a Microsoft Entra application and service principal for GitHub Actions. In the app registration, add two [federated credentials](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect) with audience `api://AzureADTokenExchange`. Use the actual GitHub owner, repository, and default branch in the subjects:

   | Job | Federated subject |
   | --- | --- |
   | Plan | `repo:OWNER/REPO:ref:refs/heads/DEFAULT_BRANCH` |
   | Apply | `repo:OWNER/REPO:environment:azure-apply` |

4. Grant the service principal permission to read and create resource groups in a sandbox subscription. The built-in Contributor role at subscription scope works for this demo. Also grant Storage Blob Data Contributor on the state container so OpenTofu can read, write, and lock state.
5. Set these GitHub Actions repository variables:

   | Variable | Value |
   | --- | --- |
   | `AZURE_CLIENT_ID` | Entra application client ID |
   | `AZURE_TENANT_ID` | Entra tenant ID |
   | `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID |
   | `STATE_STORAGE_ACCOUNT` | Existing storage account name |
   | `STATE_CONTAINER` | Existing blob container name |

6. Create the GitHub environment `azure-apply` and restrict deployments to the default branch. Configure required reviewers where your GitHub plan supports them. The example shares one Azure identity across jobs, so protect the default branch and restrict workflow edits to trusted maintainers.

## Run

Open **Actions → OpenTofu Azure → Run workflow** and select the default branch. Leave **apply** unchecked for a preview. To deploy, start a run with **apply** checked, review that run's plan log, then approve the environment deployment if required reviewers are configured. The apply job downloads the saved plan from that run and applies it. If apply fails, start a fresh run to generate a new plan.

The defaults are `rg-opentofu-example` and `eastus`. Adjust them in `main.tf` if needed. Use a dedicated group for this example because deleting an Azure resource group also deletes its contents.

## Verify the result

A first run against an empty state should propose one resource to add. After applying, look for the resource group under **Resource groups** in the Azure portal. A second preview with the same configuration should show no changes.

If authentication fails, check the federated credential subject, especially the distinction between the default-branch subject and the apply environment subject. If initialization fails with a storage authorization error, check the blob data role and storage account networking. If the saved plan becomes stale, start a fresh workflow run and review the new plan.

## Clean up

With an Azure CLI login that has access to the same subscription and state container, use the same OpenTofu version and initialize against the same state:

```sh
az login
az account set --subscription "<subscription-id>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_USE_AZUREAD=true

tofu init -lockfile=readonly \
  -backend-config="storage_account_name=<account>" \
  -backend-config="container_name=<container>" \
  -backend-config="key=example.tfstate"

tofu plan -destroy -out=destroy.tfplan
tofu apply destroy.tfplan
```

Review the destroy plan before applying it. Once cleanup succeeds, remove any dedicated Azure identity and state storage you no longer need.

## License

The plan/apply pattern was adapted from the original Hybrid Pathways example. See [LICENSE](LICENSE) for its MIT license and attribution.
