# rib

## Short introduction

rib ([r]esource [i]n [b]rowser) is a simple cli tool to quickly access your Azure resources
via your terminal. That's it. 🤷

## Prerequisites

To execute rib you need

- to have [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- to be logged in via Azure CLI (`az login`)
- to have [fzf](https://github.com/junegunn/fzf) installed

## Installation

You can install rib via brew:

```bash
brew tap andenkondor/zapfhahn
brew install andenkondor/zapfhahn/rib
```

## Configuration

To enable rib for caching resources please specify the `RIB_CONFIG_FOLDER` environment variable
to point to a valid folder where rib can write cache files to.

```bash
# in your .bashrc or so

# make sure folder .rib is present
export RIB_CONFIG_FOLDER="$HOME/.rib"
```

## rib in action

You can simply call rib from your terminal. It should then display a dialog
which lists all of your accessible Azure resources (meaning all resources in all
subscriptions of your current tenant). You can add a fuzzy search term (e.g. some keywords
like project abbrevation, environment, resource type) separated by spaces. The list will narrow then.
After finding your desired resource you can select it with arrow keys and enter. The resource will open in your
browser.

### Selecting multiple

You can open multiple resources at once by not directly hitting enter but marking each resource with the tab button.
After a final enter all marked resources are opened in a dedicated tab each. You are allowed to edit the search between marking two elements.

### Search syntax

By default the search is very fuzzy meaning you can just input words separated by spaces
in any order and rib will try to find your resource. If you want your search to be more specific please
refer to [fzf search syntax](https://github.com/junegunn/fzf?tab=readme-ov-file#search-syntax).

### Limit subscription scope

By default rib will search through all of your current tenant's subscriptions.
If you rather want to specify the subscription scope you can add a param to rib:

```bash
rib  --subscriptions=<subscription-1-uuid>,<subscription-2-uuid>,...
```

### Enable caching

To really improve your rib experience you need to enable caching.
Otherwise rib has to retrieve the Azure resources for each invocation which will
take a decent amount of time.

To run rib with caching do `rib --allow-stale-minutes=1440`.
In this example rib will only fetch Azure resources when they are older
than one day. Otherwise it'll just use the cached ones.
