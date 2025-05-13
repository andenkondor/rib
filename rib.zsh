#!/bin/zsh

# Constants
DELIMITER=$(echo -e '\t')

# Function to open a resource in the browser based on the selected line
# Format: <resourceId>$DELIMITER<resourceName>$DELIMITER<resourceGroup>$DELIMITER<resourceType>
open_resource_in_browser() {
  local resource_line="$1"
  local resource_id=$(echo "$resource_line" | awk -F "$DELIMITER" '{print $1}')
  local tenant=$(az account show --query tenantId --output tsv)
  local resource_url="https://portal.azure.com/#@${tenant}/resource${resource_id}"

  # Open URL based on operating system
  case "$OSTYPE" in
  linux*) xdg-open "$resource_url" ;;
  darwin*) open "$resource_url" ;;
  cygwin* | msys* | win32*) start "$resource_url" ;;
  *) echo "Unsupported OS: $OSTYPE" ;;
  esac
}

# Function to format a resource for display
format_resource() {
  local id="$1"
  local name="$2"
  local resource_group="$3"
  local type="$4"

  echo "$id$DELIMITER$(printf '%-80s' "$name")$DELIMITER$(printf '%-60s' "$resource_group")$DELIMITER$(printf '%-40s' "$type")"
}

# Function to get resources for a subscription (either from cache or Azure)
get_subscription_resources() {
  local subscription="$1"
  local allow_stale_minutes="$2"
  local formatted_resources=()

  # Check if we can use cached resources
  if [[ -n "${RIB_CONFIG_FOLDER}" ]]; then
    local cache_file="$RIB_CONFIG_FOLDER/cache_subscription_${subscription}.txt"

    if [ $allow_stale_minutes -ge 0 ] && [ -e "$cache_file" ] && [ $(find "$cache_file" -mmin -"$allow_stale_minutes") ]; then
      # Use cached resources
      cat "$cache_file"
      return 0
    fi
  fi

  # Fetch resources from Azure
  local subscription_resources=$(
    az resource list --subscription "$subscription" --query "[].{id:id,name:name,resourceGroup:resourceGroup,type:type}" -o tsv 2>/dev/null
  )

  # Check if the Azure CLI command was successful
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Process and format each resource
  while IFS=$'\t' read -r id name resource_group type; do
    if [ -n "$id" ]; then # Only process non-empty lines
      local formatted_resource=$(format_resource "$id" "$name" "$resource_group" "$type")
      formatted_resources+=("$formatted_resource")
      echo "$formatted_resource"
    fi
  done <<<"$subscription_resources"

  # Cache the results if caching is enabled
  if [[ -n "${RIB_CONFIG_FOLDER}" && ${#formatted_resources[@]} -gt 0 ]]; then
    printf '%s\n' "${formatted_resources[@]}" >"$cache_file"
  elif [[ -n "${formatted_resources[@]}" && -z "${RIB_CONFIG_FOLDER}" ]]; then
    echo "The current result won't be cached since you've not set RIB_CONFIG_FOLDER to allow for caching.
Please consult README."
  fi
}

# Parse command line arguments
parse_arguments() {
  local subscriptions=""
  local allow_stale_minutes=1440  # Default to one day (1440 minutes)
  local query=""

  for i in "$@"; do
    case $i in
    --subscriptions=*)
      subscriptions="${i#*=}"
      shift
      ;;
    --allow-stale-minutes=*)
      allow_stale_minutes="${i#*=}"
      shift
      ;;
    -* | --*)
      echo "Unknown option $i"
      exit 1
      ;;
    *)
      # Collect remaining arguments as the query
      if [ -n "$i" ]; then
        query="$query $i"
      fi
      ;;
    esac
  done

  # Trim leading/trailing whitespace from query
  query=$(echo "$query" | xargs)

  echo "$subscriptions|$allow_stale_minutes|$query"
}

# Main function
main() {
  # Parse arguments
  local args=$(parse_arguments "$@")
  local subscriptions=$(echo "$args" | cut -d'|' -f1)
  local allow_stale_minutes=$(echo "$args" | cut -d'|' -f2)
  local query=$(echo "$args" | cut -d'|' -f3)

  # Get list of subscriptions to process
  local subscription_list=()
  if [ -n "$subscriptions" ]; then
    subscription_list=(${(s:,:)subscriptions})
  fi

  # If no subscriptions specified, get all from current account
  if [ ${#subscription_list[@]} -eq 0 ]; then
    local az_output=$(az account list --query "[].id" --output tsv 2>/dev/null)

    # Check if az command was successful
    if [ $? -ne 0 ]; then
      echo "Error: Failed to retrieve Azure subscriptions. Please ensure you're logged in with 'az login'."
      exit 1
    fi

    while IFS= read -r line; do
      subscription_list+=("$line")
    done <<<"$az_output"
  fi

  # Collect resources from all subscriptions
  local all_resources=()

  for subscription in "${subscription_list[@]}"; do
    # Get resources for this subscription
    while IFS= read -r resource; do
      if [ -n "$resource" ]; then # Only add non-empty lines
        all_resources+=("$resource")
      fi
    done < <(get_subscription_resources "$subscription" "$allow_stale_minutes")
  done

  # If no resources found, exit with message
  if [ ${#all_resources[@]} -eq 0 ]; then
    echo "No resources found in the specified subscriptions."
    exit 0
  fi

  # If there is a query and only one matching item - directly open it in the browser without fzf
  if [ -n "$query" ]; then
    # Use grep with fixed strings to avoid interpretation of special characters in query
    local matching_resources=$(printf "%s\n" "${all_resources[@]}" | grep -F "$query")
    local match_count=$(echo "$matching_resources" | grep -v "^$" | wc -l)

    if [ "$match_count" -eq 1 ]; then
      open_resource_in_browser "$(echo "$matching_resources" | grep -v "^$")"
      exit 0
    fi
  fi

  # Check if fzf is installed
  if ! command -v fzf &>/dev/null; then
    echo "Error: fzf is not installed. Please install it to use this tool."
    echo "See: https://github.com/junegunn/fzf#installation"
    exit 1
  fi

  # Use fzf to select resources
  local selected_resources=$(printf "%s\n" "${all_resources[@]}" | fzf --query "$query" -m --with-nth=2..5 --delimiter="$DELIMITER")

  # Check if user selected anything (fzf returns empty if cancelled with Esc/Ctrl-C)
  if [ -z "$selected_resources" ]; then
    echo "No resources selected. Exiting."
    exit 0
  fi

  # Open each selected resource in browser
  while IFS= read -r line; do
    if [ -n "$line" ]; then # Only process non-empty lines
      open_resource_in_browser "$line"
    fi
  done <<<"$selected_resources"
}

# Execute main function with all arguments
main "$@"
