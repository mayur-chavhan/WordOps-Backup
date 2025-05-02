#!/bin/bash
#
# WordOps WordPress Backup Script
# Improved backup script for WordOps WordPress sites
#

# =====================================================================
# CONFIGURATION VARIABLES - MODIFY THESE AS NEEDED
# =====================================================================

# Backup settings
DEFAULT_BACKUP_DIR="$HOME/wordpress_backups"
DEFAULT_RETENTION_DAYS=30
DEFAULT_COMPRESSION="zstd"  # Options: gzip, zstd
DEFAULT_COMPRESSION_LEVEL=3 # 1-19 for zstd, 1-9 for gzip/pigz

# Notification settings
ENABLE_NOTIFICATIONS=true
NOTIFICATION_TYPE="telegram" # Options: telegram, smtp, ntfy, none

# Telegram notification settings
TELEGRAM_BOT_TOKEN="" # Your Telegram bot token
TELEGRAM_CHAT_ID=""   # Your Telegram chat ID

# SMTP notification settings
SMTP_SERVER=""                           # SMTP server address (e.g., smtp.gmail.com:587)
SMTP_USER=""                             # SMTP username
SMTP_PASSWORD=""                         # SMTP password
SMTP_FROM=""                             # From email address
SMTP_TO=""                               # To email address
SMTP_SUBJECT_PREFIX="[WordPress Backup]" # Email subject prefix

# ntfy notification settings
NTFY_URL="https://ntfy.sh" # ntfy server URL
NTFY_TOPIC=""              # Your ntfy topic
NTFY_PRIORITY="default"    # Options: min, low, default, high, urgent
NTFY_TAGS="floppy_disk"    # Emoji tags for notifications

# System settings
LOG_FILE="$HOME/wordpress_backups/backup.log"
PARALLEL_COMPRESSION=true # Use pigz for parallel gzip compression if available

# =====================================================================
# DO NOT MODIFY BELOW THIS LINE UNLESS YOU KNOW WHAT YOU'RE DOING
# =====================================================================

# Set script variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/backup-config.conf"
EXCLUDE_FILE="$SCRIPT_DIR/exclude.txt"
DATEFORM=$(date +"%Y%m%d%H%M")
START_TIME=$(date +%s)

# Create config file if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    cat >"$CONFIG_FILE" <<EOL
# WordOps WordPress Backup Configuration
BACKUP_DIR="$DEFAULT_BACKUP_DIR"
RETENTION_DAYS=$DEFAULT_RETENTION_DAYS
COMPRESSION="$DEFAULT_COMPRESSION"
COMPRESSION_LEVEL=$DEFAULT_COMPRESSION_LEVEL
ENABLE_NOTIFICATIONS=$ENABLE_NOTIFICATIONS
NOTIFICATION_TYPE="$NOTIFICATION_TYPE"

# Telegram notification settings
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"

# SMTP notification settings
SMTP_SERVER="$SMTP_SERVER"
SMTP_USER="$SMTP_USER"
SMTP_PASSWORD="$SMTP_PASSWORD"
SMTP_FROM="$SMTP_FROM"
SMTP_TO="$SMTP_TO"
SMTP_SUBJECT_PREFIX="$SMTP_SUBJECT_PREFIX"

# ntfy notification settings
NTFY_URL="$NTFY_URL"
NTFY_TOPIC="$NTFY_TOPIC"
NTFY_PRIORITY="$NTFY_PRIORITY"
NTFY_TAGS="$NTFY_TAGS"

# System settings
PARALLEL_COMPRESSION=$PARALLEL_COMPRESSION
EOL
fi

# Check if Telegram notification is enabled but credentials are missing
if [ "$NOTIFICATION_TYPE" = "telegram" ] || [ "$NOTIFICATION_TYPE" = "all" ]; then
    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        echo "Telegram notifications are enabled but credentials are missing."
        echo "Please configure your Telegram bot:"

        if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
            read -p "Enter your Telegram Bot Token: " new_token
            if [ -n "$new_token" ]; then
                TELEGRAM_BOT_TOKEN="$new_token"
                sed -i "s/TELEGRAM_BOT_TOKEN=\".*\"/TELEGRAM_BOT_TOKEN=\"$new_token\"/" "$CONFIG_FILE"
            fi
        fi

        if [ -z "$TELEGRAM_CHAT_ID" ]; then
            read -p "Enter your Telegram Chat ID: " new_chat_id
            if [ -n "$new_chat_id" ]; then
                TELEGRAM_CHAT_ID="$new_chat_id"
                sed -i "s/TELEGRAM_CHAT_ID=\".*\"/TELEGRAM_CHAT_ID=\"$new_chat_id\"/" "$CONFIG_FILE"
            fi
        fi

        echo "Telegram configuration updated."
    fi
fi

# Load configuration
source "$CONFIG_FILE"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Function to format time duration
format_duration() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local hours=$((minutes / 60))
    local days=$((hours / 24))

    if [ $days -gt 0 ]; then
        echo "${days}d ${hours% 24}h ${minutes% 60}m ${seconds% 60}s"
    elif [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes% 60}m ${seconds% 60}s"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${seconds% 60}s"
    else
        echo "${seconds}s"
    fi
}

# Function to format file size
format_size() {
    local size=$1
    local kb=$((size / 1024))
    local mb=$((kb / 1024))
    local gb=$((mb / 1024))

    if [ $gb -gt 0 ]; then
        echo "$(printf "%.2f" "$(echo "$size / 1073741824" | bc -l)")GB"
    elif [ $mb -gt 0 ]; then
        echo "$(printf "%.2f" "$(echo "$size / 1048576" | bc -l)")MB"
    elif [ $kb -gt 0 ]; then
        echo "$(printf "%.2f" "$(echo "$size / 1024" | bc -l)")KB"
    else
        echo "${size}B"
    fi
}

# Function to prepare notification message
prepare_notification_message() {
    local type="$1"
    local site="$2"
    local backup_dir="$3"
    local schedule="$4"
    local formatted_message=""
    local plain_message=""

    # Calculate time elapsed
    local end_time=$(date +%s)
    local elapsed=$((end_time - START_TIME))
    local duration=$(format_duration $elapsed)

    # Get current date and time
    local current_datetime=$(date "+%Y-%m-%d %H:%M:%S")

    # Format message based on backup type
    case "$type" in
    "full")
        # Get file sizes
        local files_size=0
        local db_size=0

        if [ "$COMPRESSION" = "zstd" ]; then
            [ -f "$backup_dir/$DATEFORM-$site-files.tar.zst" ] && files_size=$(stat -c%s "$backup_dir/$DATEFORM-$site-files.tar.zst")
            [ -f "$backup_dir/$DATEFORM-$site.sql.zst" ] && db_size=$(stat -c%s "$backup_dir/$DATEFORM-$site.sql.zst")
        else
            [ -f "$backup_dir/$DATEFORM-$site-files.tar.gz" ] && files_size=$(stat -c%s "$backup_dir/$DATEFORM-$site-files.tar.gz")
            [ -f "$backup_dir/$DATEFORM-$site.sql.gz" ] && db_size=$(stat -c%s "$backup_dir/$DATEFORM-$site.sql.gz")
        fi

        local total_size=$((files_size + db_size))
        local formatted_files_size=$(format_size $files_size)
        local formatted_db_size=$(format_size $db_size)
        local formatted_total_size=$(format_size $total_size)

        # HTML formatted message (for Telegram)
        formatted_message="🚀 <b>Full Backup Completed</b> ✅\n\n"
        formatted_message+="📂 <b>Site:</b> $site\n"
        formatted_message+="⏱️ <b>Completed at:</b> $current_datetime\n"
        formatted_message+="⌛ <b>Duration:</b> $duration\n"
        formatted_message+="💾 <b>Compression:</b> $COMPRESSION\n\n"
        formatted_message+="📊 <b>Backup Size:</b>\n"
        formatted_message+="  • Files: $formatted_files_size\n"
        formatted_message+="  • Database: $formatted_db_size\n"
        formatted_message+="  • Total: $formatted_total_size\n\n"
        formatted_message+="📁 <b>Backup Location:</b>\n$backup_dir"

        # Plain text message (for email and ntfy)
        plain_message="🚀 Full Backup Completed ✅\n\n"
        plain_message+="📂 Site: $site\n"
        plain_message+="⏱️ Completed at: $current_datetime\n"
        plain_message+="⌛ Duration: $duration\n"
        plain_message+="💾 Compression: $COMPRESSION\n\n"
        plain_message+="📊 Backup Size:\n"
        plain_message+="  • Files: $formatted_files_size\n"
        plain_message+="  • Database: $formatted_db_size\n"
        plain_message+="  • Total: $formatted_total_size\n\n"
        plain_message+="📁 Backup Location:\n$backup_dir"
        ;;

    "db")
        # Get database size
        local db_size=0

        if [ "$COMPRESSION" = "zstd" ]; then
            [ -f "$backup_dir/$DATEFORM-$site.sql.zst" ] && db_size=$(stat -c%s "$backup_dir/$DATEFORM-$site.sql.zst")
        else
            [ -f "$backup_dir/$DATEFORM-$site.sql.gz" ] && db_size=$(stat -c%s "$backup_dir/$DATEFORM-$site.sql.gz")
        fi

        local formatted_db_size=$(format_size $db_size)

        # HTML formatted message (for Telegram)
        formatted_message="💾 <b>Database Backup Completed</b> ✅\n\n"
        formatted_message+="📂 <b>Site:</b> $site\n"
        formatted_message+="⏱️ <b>Completed at:</b> $current_datetime\n"
        formatted_message+="⌛ <b>Duration:</b> $duration\n"
        formatted_message+="💾 <b>Compression:</b> $COMPRESSION\n\n"
        formatted_message+="📊 <b>Database Size:</b> $formatted_db_size\n\n"
        formatted_message+="📁 <b>Backup Location:</b>\n$backup_dir"

        # Plain text message (for email and ntfy)
        plain_message="💾 Database Backup Completed ✅\n\n"
        plain_message+="📂 Site: $site\n"
        plain_message+="⏱️ Completed at: $current_datetime\n"
        plain_message+="⌛ Duration: $duration\n"
        plain_message+="💾 Compression: $COMPRESSION\n\n"
        plain_message+="📊 Database Size: $formatted_db_size\n\n"
        plain_message+="📁 Backup Location:\n$backup_dir"
        ;;

    "incremental")
        # Get file sizes
        local files_size=0
        local db_size=0

        if [ "$COMPRESSION" = "zstd" ]; then
            [ -f "$backup_dir/$DATEFORM-$site-incremental.tar.zst" ] && files_size=$(stat -c%s "$backup_dir/$DATEFORM-$site-incremental.tar.zst")
            [ -f "$backup_dir/$DATEFORM-$site.sql.zst" ] && db_size=$(stat -c%s "$backup_dir/$DATEFORM-$site.sql.zst")
        else
            [ -f "$backup_dir/$DATEFORM-$site-incremental.tar.gz" ] && files_size=$(stat -c%s "$backup_dir/$DATEFORM-$site-incremental.tar.gz")
            [ -f "$backup_dir/$DATEFORM-$site.sql.gz" ] && db_size=$(stat -c%s "$backup_dir/$DATEFORM-$site.sql.gz")
        fi

        local total_size=$((files_size + db_size))
        local formatted_files_size=$(format_size $files_size)
        local formatted_db_size=$(format_size $db_size)
        local formatted_total_size=$(format_size $total_size)

        # HTML formatted message (for Telegram)
        formatted_message="🔄 <b>Incremental Backup Completed</b> ✅\n\n"
        formatted_message+="📂 <b>Site:</b> $site\n"
        formatted_message+="⏱️ <b>Completed at:</b> $current_datetime\n"
        formatted_message+="⌛ <b>Duration:</b> $duration\n"
        formatted_message+="💾 <b>Compression:</b> $COMPRESSION\n\n"
        formatted_message+="📊 <b>Backup Size:</b>\n"
        formatted_message+="  • Changed Files: $formatted_files_size\n"
        formatted_message+="  • Database: $formatted_db_size\n"
        formatted_message+="  • Total: $formatted_total_size\n\n"
        formatted_message+="📁 <b>Backup Location:</b>\n$backup_dir"

        # Plain text message (for email and ntfy)
        plain_message="🔄 Incremental Backup Completed ✅\n\n"
        plain_message+="📂 Site: $site\n"
        plain_message+="⏱️ Completed at: $current_datetime\n"
        plain_message+="⌛ Duration: $duration\n"
        plain_message+="💾 Compression: $COMPRESSION\n\n"
        plain_message+="📊 Backup Size:\n"
        plain_message+="  • Changed Files: $formatted_files_size\n"
        plain_message+="  • Database: $formatted_db_size\n"
        plain_message+="  • Total: $formatted_total_size\n\n"
        plain_message+="📁 Backup Location:\n$backup_dir"
        ;;

    "cron")
        # HTML formatted message (for Telegram)
        formatted_message="⏰ <b>Backup Schedule Updated</b>\n\n"
        formatted_message+="📂 <b>Site:</b> $site\n"
        formatted_message+="🔄 <b>Type:</b> $backup_dir\n"
        formatted_message+="📅 <b>Schedule:</b> $schedule"

        # Plain text message (for email and ntfy)
        plain_message="⏰ Backup Schedule Updated\n\n"
        plain_message+="📂 Site: $site\n"
        plain_message+="🔄 Type: $backup_dir\n"
        plain_message+="📅 Schedule: $schedule"
        ;;

    *)
        # Use the provided message directly
        formatted_message="$schedule"
        plain_message="$schedule"
        ;;
    esac

    # Return both formatted and plain messages
    echo -e "$formatted_message\n---PLAIN_TEXT_SEPARATOR---\n$plain_message"
}

# Function to send Telegram notifications
send_telegram_notification() {
    local message="$1"

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        log_message "Telegram notification failed: Missing bot token or chat ID"
        return 1
    fi

    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$message" \
        -d parse_mode="HTML" >/dev/null

    if [ $? -eq 0 ]; then
        log_message "Telegram notification sent successfully"
        return 0
    else
        log_message "Failed to send Telegram notification"
        return 1
    fi
}

# Function to send email notifications via SMTP
send_smtp_notification() {
    local subject="$1"
    local message="$2"
    local log_file="$3"

    if [ -z "$SMTP_SERVER" ] || [ -z "$SMTP_USER" ] || [ -z "$SMTP_PASSWORD" ] || [ -z "$SMTP_FROM" ] || [ -z "$SMTP_TO" ]; then
        log_message "SMTP notification failed: Missing SMTP configuration"
        return 1
    fi

    # Create a temporary file for the email content
    local tmp_file=$(mktemp)

    # Write email headers
    echo "From: $SMTP_FROM" >"$tmp_file"
    echo "To: $SMTP_TO" >>"$tmp_file"
    echo "Subject: $subject" >>"$tmp_file"
    echo "MIME-Version: 1.0" >>"$tmp_file"
    echo "Content-Type: multipart/mixed; boundary=boundary-string" >>"$tmp_file"
    echo "" >>"$tmp_file"

    # Write email body
    echo "--boundary-string" >>"$tmp_file"
    echo "Content-Type: text/plain; charset=utf-8" >>"$tmp_file"
    echo "Content-Transfer-Encoding: 8bit" >>"$tmp_file"
    echo "" >>"$tmp_file"
    echo "$message" >>"$tmp_file"
    echo "" >>"$tmp_file"

    # Attach log file if it exists
    if [ -n "$log_file" ] && [ -f "$log_file" ]; then
        echo "--boundary-string" >>"$tmp_file"
        echo "Content-Type: text/plain; charset=utf-8; name=\"backup.log\"" >>"$tmp_file"
        echo "Content-Transfer-Encoding: 8bit" >>"$tmp_file"
        echo "Content-Disposition: attachment; filename=\"backup.log\"" >>"$tmp_file"
        echo "" >>"$tmp_file"
        cat "$log_file" >>"$tmp_file"
        echo "" >>"$tmp_file"
    fi

    echo "--boundary-string--" >>"$tmp_file"

    # Send the email using curl
    curl -s --url "smtp://$SMTP_SERVER" \
        --mail-from "$SMTP_FROM" \
        --mail-rcpt "$SMTP_TO" \
        --upload-file "$tmp_file" \
        --user "$SMTP_USER:$SMTP_PASSWORD" \
        --ssl-reqd >/dev/null

    local result=$?
    rm -f "$tmp_file"

    if [ $result -eq 0 ]; then
        log_message "SMTP notification sent successfully"
        return 0
    else
        log_message "Failed to send SMTP notification"
        return 1
    fi
}

# Function to send ntfy notifications
send_ntfy_notification() {
    local title="$1"
    local message="$2"

    if [ -z "$NTFY_TOPIC" ]; then
        log_message "ntfy notification failed: Missing topic"
        return 1
    fi

    curl -s -H "Title: $title" \
        -H "Priority: $NTFY_PRIORITY" \
        -H "Tags: $NTFY_TAGS" \
        -d "$message" \
        "$NTFY_URL/$NTFY_TOPIC" >/dev/null

    if [ $? -eq 0 ]; then
        log_message "ntfy notification sent successfully"
        return 0
    else
        log_message "Failed to send ntfy notification"
        return 1
    fi
}

# Main notification function
send_notification() {
    local message="$1"
    local type="$2"
    local site="$3"
    local backup_dir="$4"

    # Skip if notifications are disabled
    if [ "$ENABLE_NOTIFICATIONS" != true ]; then
        log_message "Notifications disabled"
        return
    fi

    # Prepare notification message
    local notification_data=$(prepare_notification_message "$type" "$site" "$backup_dir" "$message")
    local html_message=$(echo "$notification_data" | sed -n '1,/---PLAIN_TEXT_SEPARATOR---/p' | sed '/---PLAIN_TEXT_SEPARATOR---/d')
    local plain_message=$(echo "$notification_data" | sed -n '/---PLAIN_TEXT_SEPARATOR---/,$p' | sed '1d')

    # Send notifications based on configured type
    case "$NOTIFICATION_TYPE" in
    "telegram")
        send_telegram_notification "$html_message"
        ;;
    "smtp")
        local subject="$SMTP_SUBJECT_PREFIX WordPress Backup: $site"
        if [ "$type" = "full" ]; then
            subject="$SMTP_SUBJECT_PREFIX Full Backup Completed: $site"
        elif [ "$type" = "db" ]; then
            subject="$SMTP_SUBJECT_PREFIX Database Backup Completed: $site"
        elif [ "$type" = "incremental" ]; then
            subject="$SMTP_SUBJECT_PREFIX Incremental Backup Completed: $site"
        elif [ "$type" = "cron" ]; then
            subject="$SMTP_SUBJECT_PREFIX Backup Schedule Updated: $site"
        fi
        send_smtp_notification "$subject" "$plain_message" "$LOG_FILE"
        ;;
    "ntfy")
        local title="WordPress Backup: $site"
        if [ "$type" = "full" ]; then
            title="Full Backup Completed: $site"
        elif [ "$type" = "db" ]; then
            title="Database Backup Completed: $site"
        elif [ "$type" = "incremental" ]; then
            title="Incremental Backup Completed: $site"
        elif [ "$type" = "cron" ]; then
            title="Backup Schedule Updated: $site"
        fi
        send_ntfy_notification "$title" "$plain_message"
        ;;
    "all")
        send_telegram_notification "$html_message"

        local subject="$SMTP_SUBJECT_PREFIX WordPress Backup: $site"
        if [ "$type" = "full" ]; then
            subject="$SMTP_SUBJECT_PREFIX Full Backup Completed: $site"
        elif [ "$type" = "db" ]; then
            subject="$SMTP_SUBJECT_PREFIX Database Backup Completed: $site"
        elif [ "$type" = "incremental" ]; then
            subject="$SMTP_SUBJECT_PREFIX Incremental Backup Completed: $site"
        elif [ "$type" = "cron" ]; then
            subject="$SMTP_SUBJECT_PREFIX Backup Schedule Updated: $site"
        fi
        send_smtp_notification "$subject" "$plain_message" "$LOG_FILE"

        local title="WordPress Backup: $site"
        if [ "$type" = "full" ]; then
            title="Full Backup Completed: $site"
        elif [ "$type" = "db" ]; then
            title="Database Backup Completed: $site"
        elif [ "$type" = "incremental" ]; then
            title="Incremental Backup Completed: $site"
        elif [ "$type" = "cron" ]; then
            title="Backup Schedule Updated: $site"
        fi
        send_ntfy_notification "$title" "$plain_message"
        ;;
    "none")
        log_message "Notifications type set to 'none', skipping notifications"
        ;;
    *)
        log_message "Unknown notification type: $NOTIFICATION_TYPE"
        ;;
    esac
}

# Function to check if site is a valid WordPress installation
check_wordpress() {
    local site="$1"

    if [ ! -e "/var/www/$site/wp-config.php" ]; then
        log_message "ERROR: $site does not appear to be a valid WordPress site!"
        return 1
    fi

    return 0
}

# Function to find WordPress sites in /var/www
find_wordpress_sites() {
    local sites=()
    local count=0

    # Check if /var/www exists
    if [ ! -d "/var/www" ]; then
        log_message "ERROR: /var/www directory not found!"
        return 1
    fi

    # Find directories in /var/www that contain wp-config.php
    for dir in /var/www/*/; do
        if [ -e "${dir}wp-config.php" ]; then
            site=$(basename "$dir")
            sites+=("$site")
            count=$((count + 1))
        fi
    done

    # If no WordPress sites found
    if [ $count -eq 0 ]; then
        log_message "No WordPress sites found in /var/www"
        return 1
    fi

    # Print the list of WordPress sites
    echo "Found $count WordPress sites:"
    for i in "${!sites[@]}"; do
        echo "$((i + 1)). ${sites[$i]}"
    done

    # Return the list of sites
    echo "${sites[@]}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to perform full backup (files + database)
full_backup() {
    local site="$1"
    local backup_dir="$BACKUP_DIR/$site/$DATEFORM"
    local site_path="/var/www/$site/htdocs"
    local files_start_time
    local files_end_time
    local db_start_time
    local db_end_time

    log_message "Starting full backup for $site..."
    mkdir -p "$backup_dir"

    # Backup files
    log_message "Backing up files to $backup_dir..."
    files_start_time=$(date +%s)

    if [ "$COMPRESSION" = "zstd" ]; then
        tar --zstd -cf "$backup_dir/$DATEFORM-$site-files.tar.zst" \
            --exclude-from="$EXCLUDE_FILE" -C "$site_path" .
    else
        # Check if pigz is available and parallel compression is enabled
        if command_exists pigz && [ "$PARALLEL_COMPRESSION" = true ]; then
            log_message "Using pigz for parallel compression"
            tar -I "pigz -$COMPRESSION_LEVEL" -cf "$backup_dir/$DATEFORM-$site-files.tar.gz" \
                --exclude-from="$EXCLUDE_FILE" -C "$site_path" .
        else
            tar -czf "$backup_dir/$DATEFORM-$site-files.tar.gz" \
                --exclude-from="$EXCLUDE_FILE" -C "$site_path" .
        fi
    fi

    files_end_time=$(date +%s)
    local files_duration=$((files_end_time - files_start_time))
    log_message "Files backup completed in $(format_duration $files_duration)"

    # Backup WordPress config file
    cp "/var/www/$site/wp-config.php" "$backup_dir"

    # Backup database
    log_message "Backing up WordPress database..."
    db_start_time=$(date +%s)
    cd "$site_path" || exit
    # Fix for mysqldump deprecation warning
    export MYSQL_PWD="$(grep -oP "(?<=DB_PASSWORD', ')[^']+" /var/www/$site/wp-config.php)"
    wp db export "$backup_dir/$DATEFORM-$site.sql" --allow-root

    # Compress database dump
    if [ "$COMPRESSION" = "zstd" ]; then
        zstd -f -$COMPRESSION_LEVEL "$backup_dir/$DATEFORM-$site.sql" -o "$backup_dir/$DATEFORM-$site.sql.zst"
        rm "$backup_dir/$DATEFORM-$site.sql"
    else
        # Check if pigz is available and parallel compression is enabled
        if command_exists pigz && [ "$PARALLEL_COMPRESSION" = true ]; then
            pigz -$COMPRESSION_LEVEL -f "$backup_dir/$DATEFORM-$site.sql"
        else
            gzip -$COMPRESSION_LEVEL -f "$backup_dir/$DATEFORM-$site.sql"
        fi
    fi

    db_end_time=$(date +%s)
    local db_duration=$((db_end_time - db_start_time))
    log_message "Database backup completed in $(format_duration $db_duration)"

    log_message "Full backup completed for $site"
    send_notification "" "full" "$site" "$backup_dir"
}

# Function to perform database-only backup
db_backup() {
    local site="$1"
    local backup_dir="$BACKUP_DIR/$site/$DATEFORM-db"
    local site_path="/var/www/$site/htdocs"
    local db_start_time
    local db_end_time

    log_message "Starting database-only backup for $site..."
    mkdir -p "$backup_dir"

    # Backup WordPress config file
    cp "/var/www/$site/wp-config.php" "$backup_dir"

    # Backup database
    log_message "Backing up WordPress database..."
    db_start_time=$(date +%s)
    cd "$site_path" || exit
    # Fix for mysqldump deprecation warning
    export MYSQL_PWD="$(grep -oP "(?<=DB_PASSWORD', ')[^']+" /var/www/$site/wp-config.php)"
    wp db export "$backup_dir/$DATEFORM-$site.sql" --allow-root

    # Compress database dump
    if [ "$COMPRESSION" = "zstd" ]; then
        zstd -f -$COMPRESSION_LEVEL "$backup_dir/$DATEFORM-$site.sql" -o "$backup_dir/$DATEFORM-$site.sql.zst"
        rm "$backup_dir/$DATEFORM-$site.sql"
    else
        # Check if pigz is available and parallel compression is enabled
        if command_exists pigz && [ "$PARALLEL_COMPRESSION" = true ]; then
            pigz -$COMPRESSION_LEVEL -f "$backup_dir/$DATEFORM-$site.sql"
        else
            gzip -$COMPRESSION_LEVEL -f "$backup_dir/$DATEFORM-$site.sql"
        fi
    fi

    db_end_time=$(date +%s)
    local db_duration=$((db_end_time - db_start_time))
    log_message "Database backup completed in $(format_duration $db_duration)"

    log_message "Database backup completed for $site"
    send_notification "" "db" "$site" "$backup_dir"
}

# Function to perform incremental backup
incremental_backup() {
    local site="$1"
    local backup_dir="$BACKUP_DIR/$site/incremental/$DATEFORM"
    local site_path="/var/www/$site/htdocs"
    local last_full_backup
    local files_start_time
    local files_end_time
    local db_start_time
    local db_end_time

    log_message "Starting incremental backup for $site..."
    mkdir -p "$backup_dir"

    # Find the most recent full backup (excluding db-only backups)
    last_full_backup=$(find "$BACKUP_DIR/$site" -maxdepth 1 -type d -name "[0-9]*" | grep -v "\-db$" | sort -r | head -n 1)

    if [ -z "$last_full_backup" ]; then
        log_message "No full backup found. Performing full backup instead..."
        full_backup "$site"
        return
    fi

    log_message "Using reference backup: $last_full_backup"

    # Backup files that have changed since the last full backup
    log_message "Backing up changed files to $backup_dir..."
    files_start_time=$(date +%s)

    find "$site_path" -type f -newer "$last_full_backup" | grep -v -f "$EXCLUDE_FILE" >"$backup_dir/changed_files.txt"

    if [ -s "$backup_dir/changed_files.txt" ]; then
        if [ "$COMPRESSION" = "zstd" ]; then
            tar --zstd -cf "$backup_dir/$DATEFORM-$site-incremental.tar.zst" -T "$backup_dir/changed_files.txt"
        else
            # Check if pigz is available and parallel compression is enabled
            if command_exists pigz && [ "$PARALLEL_COMPRESSION" = true ]; then
                log_message "Using pigz for parallel compression"
                tar -I "pigz -$COMPRESSION_LEVEL" -cf "$backup_dir/$DATEFORM-$site-incremental.tar.gz" -T "$backup_dir/changed_files.txt"
            else
                tar -czf "$backup_dir/$DATEFORM-$site-incremental.tar.gz" -T "$backup_dir/changed_files.txt"
            fi
        fi

        files_end_time=$(date +%s)
        local files_duration=$((files_end_time - files_start_time))
        log_message "Changed files backup completed in $(format_duration $files_duration)"
    else
        log_message "No files have changed since the last full backup"
    fi

    # Backup database
    log_message "Backing up WordPress database..."
    db_start_time=$(date +%s)
    cd "$site_path" || exit
    # Fix for mysqldump deprecation warning
    export MYSQL_PWD="$(grep -oP "(?<=DB_PASSWORD', ')[^']+" /var/www/$site/wp-config.php)"
    wp db export "$backup_dir/$DATEFORM-$site.sql" --allow-root

    # Compress database dump
    if [ "$COMPRESSION" = "zstd" ]; then
        zstd -f -$COMPRESSION_LEVEL "$backup_dir/$DATEFORM-$site.sql" -o "$backup_dir/$DATEFORM-$site.sql.zst"
        rm "$backup_dir/$DATEFORM-$site.sql"
    else
        # Check if pigz is available and parallel compression is enabled
        if command_exists pigz && [ "$PARALLEL_COMPRESSION" = true ]; then
            pigz -$COMPRESSION_LEVEL -f "$backup_dir/$DATEFORM-$site.sql"
        else
            gzip -$COMPRESSION_LEVEL -f "$backup_dir/$DATEFORM-$site.sql"
        fi
    fi

    db_end_time=$(date +%s)
    local db_duration=$((db_end_time - db_start_time))
    log_message "Database backup completed in $(format_duration $db_duration)"

    log_message "Incremental backup completed for $site"
    send_notification "" "incremental" "$site" "$backup_dir"
}

# Function to clean up old backups
cleanup_backups() {
    local site="$1"
    local backup_base="$BACKUP_DIR/$site"

    log_message "Cleaning up old backups for $site (older than $RETENTION_DAYS days)..."

    # Find and remove full backups older than retention period
    find "$backup_base" -maxdepth 1 -type d -name "[0-9]*" -mtime +"$RETENTION_DAYS" -exec rm -rf {} \;

    # Find and remove incremental backups older than retention period
    find "$backup_base/incremental" -maxdepth 1 -type d -name "[0-9]*" -mtime +"$RETENTION_DAYS" -exec rm -rf {} \;

    # Find and remove database-only backups older than retention period
    find "$backup_base" -maxdepth 1 -type d -name "[0-9]*-db" -mtime +"$RETENTION_DAYS" -exec rm -rf {} \;

    log_message "Cleanup completed for $site"
}

# Function to install or update cron jobs
setup_cron() {
    local site="$1"
    local backup_type="$2"
    local schedule="$3"
    local cron_job

    case "$backup_type" in
    full)
        cron_job="$schedule $SCRIPT_DIR/wordpress-backup.sh --full $site"
        ;;
    db)
        cron_job="$schedule $SCRIPT_DIR/wordpress-backup.sh --db $site"
        ;;
    incremental)
        cron_job="$schedule $SCRIPT_DIR/wordpress-backup.sh --incremental $site"
        ;;
    *)
        log_message "Invalid backup type for cron job: $backup_type"
        return 1
        ;;
    esac

    # Remove existing cron job for this site and backup type
    crontab -l | grep -v "$SCRIPT_DIR/wordpress-backup.sh --$backup_type $site" | crontab -

    # Add new cron job
    (
        crontab -l 2>/dev/null
        echo "$cron_job"
    ) | crontab -

    log_message "Cron job for $backup_type backup of $site has been set to run $schedule"
    send_notification "$schedule" "cron" "$site" "$backup_type"
}

# Function to configure backup settings
configure_settings() {
    echo "Configure Backup Settings"
    echo "========================="
    echo "Current settings:"
    echo "Backup directory: $BACKUP_DIR"
    echo "Retention period: $RETENTION_DAYS days"
    echo "Compression method: $COMPRESSION"
    echo "Compression level: $COMPRESSION_LEVEL"
    echo "Notifications enabled: $ENABLE_NOTIFICATIONS"
    echo "Notification type: $NOTIFICATION_TYPE"
    echo "========================="
    echo

    read -p "Enter backup directory [$BACKUP_DIR]: " new_backup_dir
    read -p "Enter retention period in days [$RETENTION_DAYS]: " new_retention_days
    read -p "Enter compression method (gzip/zstd) [$COMPRESSION]: " new_compression
    read -p "Enter compression level (1-9 for gzip, 1-19 for zstd) [$COMPRESSION_LEVEL]: " new_compression_level
    read -p "Enable notifications (true/false) [$ENABLE_NOTIFICATIONS]: " new_enable_notifications
    read -p "Notification type (telegram/smtp/ntfy/all/none) [$NOTIFICATION_TYPE]: " new_notification_type

    # Update settings if provided
    if [ -n "$new_backup_dir" ]; then
        sed -i "s|BACKUP_DIR=\".*\"|BACKUP_DIR=\"$new_backup_dir\"|" "$CONFIG_FILE"
    fi

    if [ -n "$new_retention_days" ]; then
        sed -i "s/RETENTION_DAYS=.*/RETENTION_DAYS=$new_retention_days/" "$CONFIG_FILE"
    fi

    if [ -n "$new_compression" ]; then
        if [ "$new_compression" = "gzip" ] || [ "$new_compression" = "zstd" ]; then
            sed -i "s/COMPRESSION=\".*\"/COMPRESSION=\"$new_compression\"/" "$CONFIG_FILE"
        else
            echo "Invalid compression method. Using default: $COMPRESSION"
        fi
    fi

    if [ -n "$new_compression_level" ]; then
        if [[ "$new_compression_level" =~ ^[0-9]+$ ]]; then
            if [ "$COMPRESSION" = "zstd" ] && [ "$new_compression_level" -ge 1 ] && [ "$new_compression_level" -le 19 ]; then
                sed -i "s/COMPRESSION_LEVEL=.*/COMPRESSION_LEVEL=$new_compression_level/" "$CONFIG_FILE"
            elif [ "$COMPRESSION" = "gzip" ] && [ "$new_compression_level" -ge 1 ] && [ "$new_compression_level" -le 9 ]; then
                sed -i "s/COMPRESSION_LEVEL=.*/COMPRESSION_LEVEL=$new_compression_level/" "$CONFIG_FILE"
            else
                echo "Invalid compression level for $COMPRESSION. Using default: $COMPRESSION_LEVEL"
            fi
        else
            echo "Invalid compression level. Using default: $COMPRESSION_LEVEL"
        fi
    fi

    if [ -n "$new_enable_notifications" ]; then
        if [ "$new_enable_notifications" = "true" ] || [ "$new_enable_notifications" = "false" ]; then
            sed -i "s/ENABLE_NOTIFICATIONS=.*/ENABLE_NOTIFICATIONS=$new_enable_notifications/" "$CONFIG_FILE"
        else
            echo "Invalid value for enable notifications. Using default: $ENABLE_NOTIFICATIONS"
        fi
    fi

    if [ -n "$new_notification_type" ]; then
        if [ "$new_notification_type" = "telegram" ] || [ "$new_notification_type" = "smtp" ] || [ "$new_notification_type" = "ntfy" ] || [ "$new_notification_type" = "all" ] || [ "$new_notification_type" = "none" ]; then
            sed -i "s/NOTIFICATION_TYPE=\".*\"/NOTIFICATION_TYPE=\"$new_notification_type\"/" "$CONFIG_FILE"

            # Configure notification settings based on type
            case "$new_notification_type" in
            "telegram")
                echo
                echo "Configure Telegram Notifications"
                echo "==============================="
                read -p "Enter Telegram Bot Token [$TELEGRAM_BOT_TOKEN]: " new_telegram_bot_token
                read -p "Enter Telegram Chat ID [$TELEGRAM_CHAT_ID]: " new_telegram_chat_id

                if [ -n "$new_telegram_bot_token" ]; then
                    sed -i "s/TELEGRAM_BOT_TOKEN=\".*\"/TELEGRAM_BOT_TOKEN=\"$new_telegram_bot_token\"/" "$CONFIG_FILE"
                fi

                if [ -n "$new_telegram_chat_id" ]; then
                    sed -i "s/TELEGRAM_CHAT_ID=\".*\"/TELEGRAM_CHAT_ID=\"$new_telegram_chat_id\"/" "$CONFIG_FILE"
                fi
                ;;

            "smtp")
                echo
                echo "Configure SMTP Notifications"
                echo "======================================="
                read -p "Enter SMTP Server (e.g., smtp.gmail.com:587) [$SMTP_SERVER]: " new_smtp_server
                read -p "Enter SMTP Username [$SMTP_USER]: " new_smtp_user
                read -p "Enter SMTP Password [$SMTP_PASSWORD]: " new_smtp_password
                read -p "Enter From Email Address [$SMTP_FROM]: " new_smtp_from
                read -p "Enter To Email Address [$SMTP_TO]: " new_smtp_to
                read -p "Enter Email Subject Prefix [$SMTP_SUBJECT_PREFIX]: " new_smtp_subject_prefix
                echo ========================================"


                if [ -n "$new_smtp_server" ]; then
                    sed -i "s/SMTP_SERVER=\".*\"/SMTP_SERVER=\"$new_smtp_server\"/" "$CONFIG_FILE"
                fi

                if [ -n "$new_smtp_user" ]; then
                    sed -i "s/SMTP_USER=\".*\"/SMTP_USER=\"$new_smtp_user\"/" "$CONFIG_FILE"
                fi

                if [ -n "$new_smtp_password" ]; then
                    sed -i "s/SMTP_PASSWORD=\".*\"/SMTP_PASSWORD=\"$new_smtp_password\"/" "$CONFIG_FILE"
                fi

                if [ -n "$new_smtp_from" ]; then
                    sed -i "s/SMTP_FROM=\".*\"/SMTP_FROM=\"$new_smtp_from\"/" "$CONFIG_FILE"
                fi

                if [ -n "$new_smtp_to" ]; then
                    sed -i "s/SMTP_TO=\".*\"/SMTP_TO=\"$new_smtp_to\"/" "$CONFIG_FILE"
                fi

                if [ -n "$new_smtp_subject_prefix" ]; then
                    sed -i "s/SMTP_SUBJECT_PREFIX=\".*\"/SMTP_SUBJECT_PREFIX=\"$new_smtp_subject_prefix\"/" "$CONFIG_FILE"
                fi
                ;;

            "ntfy")
                echo
                echo "Configure ntfy Notifications"
                echo "==========================="
                read -p "Enter ntfy URL [$NTFY_URL]: " new_ntfy_url
                read -p "Enter ntfy Topic [$NTFY_TOPIC]: " new_ntfy_topic
                read -p "Enter ntfy Priority [min/low/default/high/urgent]: " new_ntfy_priority
                read -p "Enter ntfy Tags [$NTFY_TAGS]: " new_ntfy_tags

                if [ -n "$new_ntfy_url" ]; then
                    sed -i "s | NTFY_URL=\".*\" | NTFY_URL=\"$new_ntfy_url\" | " "$CONFIG_FILE"
                fi

                if [ -n "$new_ntfy_topic" ]; then
                    sed -i "s/NTFY_TOPIC=\".*\"/NTFY_TOPIC=\"$new_ntfy_topic\"/" "$CONFIG_FILE"
                fi

                if [ -n "$new_ntfy_priority" ]; then
                    if [ "$new_ntfy_priority" = "min" ] || [ "$new_ntfy_priority" = "low" ] || [ "$new_ntfy_priority" = "default" ] || [ "$new_ntfy_priority" = "high" ] || [ "$new_ntfy_priority" = "urgent" ]; then
                        sed -i "s/NTFY_PRIORITY=\".*\"/NTFY_PRIORITY=\"$new_ntfy_priority\"/" "$CONFIG_FILE"
                    else
                        echo "Invalid ntfy priority. Using default: $NTFY_PRIORITY"
                    fi
                fi

                if [ -n "$new_ntfy_tags" ]; then
                    sed -i "s/NTFY_TAGS=\".*\"/NTFY_TAGS=\"$new_ntfy_tags\"/" "$CONFIG_FILE"
                fi
                ;;

            "all")
                # Configure all notification types
                echo
                echo "Configure All Notification Types"
                echo "==============================="

                # Telegram
                echo
                echo "Configure Telegram Notifications"
                echo "==============================="
                read -p "Enter Telegram Bot Token [$TELEGRAM_BOT_TOKEN]: " new_telegram_bot_token
                read -p "Enter Telegram Chat ID [$TELEGRAM_CHAT_ID]: " new_telegram_chat_id

                if [ -n "$new_telegram_bot_token" ]; then
                    sed -i "s/TELEGRAM_BOT_TOKEN=\".*\"/TELEGRAM_BOT_TOKEN=\"$new_telegram_bot_token\"/" "$CONFIG_FILE"
                fi

                if [ -n "$new_telegram_chat_id" ]; then
                    sed -i "s/TELEGRAM_CHAT_ID=\".*\"/TELEGRAM_CHAT_ID=\"$new_telegram_chat_id\"/" "$CONFIG_FILE"
                fi

                # SMTP
                echo
                echo "Configure SMTP Notifications"
                echo "==========================="
                read -p "Enter SMTP Server [example: smtp.gmail.com:587]: " new_smtp_server
                read -p "Enter SMTP Username [$SMTP_USER]: " new_smtp_user
                read -p "Enter SMTP Password [$SMTP_PASSWORD]: " new_smtp_password
                read -p "Enter From Email Address [$SMTP_FROM]: " new_smtp_from
                read -p "Enter To Email Address [$SMTP_TO]: " new_smtp_to
                read -p "Enter Email Subject Prefix [$SMTP_SUBJECT_PREFIX]: " new_smtp_subject_prefix
                echo ========================================"

                if [ -n "$new_smtp_server" ]; then
                    sed -i "s/SMTP_SERVER=\".*\"/SMTP_SERVER=\"$new_smtp_server\"/" "$CONFIG_FILE"
                fi

                if [ -n "$new_smtp_user" ]; then
                    sed -i "s/SMTP_USER=\".*\"/SMTP_USER=\"$new_smtp_user\"/" "$CONFIG_FILE"
                fi

                if [ -n "$new_smtp_password" ]; then
                    sed -i "s/SMTP_PASSWORD=\".*\"/SMTP_PASSWORD=\"$new_smtp_password\"/" "$CONFIG_FILE"
                fi

                if [ -n "$new_smtp_from" ]; then
                    sed -i "s/SMTP_FROM=\".*\"/SMTP_FROM=\"$new_smtp_from\"/" "$CONFIG_FILE"
                fi

                if [ -n "$new_smtp_to" ]; then
                    sed -i "s/SMTP_TO=\".*\"/SMTP_TO=\"$new_smtp_to\"/" "$CONFIG_FILE"
                fi

                if [ -n "$new_smtp_subject_prefix" ]; then
                    sed -i "s/SMTP_SUBJECT_PREFIX=\".*\"/SMTP_SUBJECT_PREFIX=\"$new_smtp_subject_prefix\"/" "$CONFIG_FILE"
                fi

                # ntfy
                echo
                echo "Configure ntfy Notifications"
                echo "==========================="
                read -p "Enter ntfy URL [$NTFY_URL]: " new_ntfy_url
                read -p "Enter ntfy Topic [$NTFY_TOPIC]: " new_ntfy_topic
                read -p "Enter ntfy Priority (min/low/default/high/urgent) [$NTFY_PRIORITY]: " new_ntfy_priority
                read -p "Enter ntfy Tags [$NTFY_TAGS]: " new_ntfy_tags

                if [ -n "$new_ntfy_url" ]; then
                    sed -i "s|NTFY_URL=\".*\"|NTFY_URL=\"$new_ntfy_url\"|" "$CONFIG_FILE"
                fi

                if [ -n "$new_ntfy_topic" ]; then
                    sed -i "s/NTFY_TOPIC=\".*\"/NTFY_TOPIC=\"$new_ntfy_topic\"/" "$CONFIG_FILE"
                fi

                if [ -n "$new_ntfy_priority" ]; then
                    if [ "$new_ntfy_priority" = "min" ] || [ "$new_ntfy_priority" = "low" ] || [ "$new_ntfy_priority" = "default" ] || [ "$new_ntfy_priority" = "high" ] || [ "$new_ntfy_priority" = "urgent" ]; then
                        sed -i "s/NTFY_PRIORITY=\".*\"/NTFY_PRIORITY=\"$new_ntfy_priority\"/" "$CONFIG_FILE"
                    else
                        echo "Invalid ntfy priority. Using default: $NTFY_PRIORITY"
                    fi
                fi

                if [ -n "$new_ntfy_tags" ]; then
                    sed -i "s/NTFY_TAGS=\".*\"/NTFY_TAGS=\"$new_ntfy_tags\"/" "$CONFIG_FILE"
                fi
                ;;
            esac
        else
            echo "Invalid notification type. Using default: $NOTIFICATION_TYPE"
        fi
    fi

    echo "Settings updated successfully"

    # Reload config
    source "$CONFIG_FILE"
}

# Function to select a WordPress site
select_wordpress_site() {
    # Find WordPress sites
    local sites_output=$(find_wordpress_sites)
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "No WordPress sites found. Please check your installation."
        return 1
    fi

    # Parse the output to get the list of sites
    local sites=()
    while read -r line; do
        if [[ $line =~ ^[0-9]+\..* ]]; then
            # Skip the numbered lines
            continue
        elif [[ $line == "Found"* ]]; then
            # Skip the "Found X WordPress sites:" line
            continue
        else
            # Add site to the array
            sites+=($line)
        fi
    done <<<"$sites_output"

    # If only one site is found, select it automatically
    if [ ${#sites[@]} -eq 1 ]; then
        echo "Automatically selected the only available site: ${sites[0]}"
        echo "${sites[0]}"
        return 0
    fi

    # Prompt user to select a site
    echo "Select a WordPress site:"
    for i in "${!sites[@]}"; do
        echo "$((i + 1)). ${sites[$i]}"
    done

    local valid_selection=false
    local selection

    while [ "$valid_selection" = false ]; do
        read -p "Enter site number [1-${#sites[@]}]: " selection

        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#sites[@]}" ]; then
            valid_selection=true
        else
            echo "Invalid selection. Please enter a number between 1 and ${#sites[@]}."
        fi
    done

    # Return the selected site
    echo "${sites[$((selection - 1))]}"
    return 0
}

# Function to display the main menu
show_menu() {
    clear
    echo "WordOps | WordPress Backup Script Menu | Author : Mayur G. Chavhan"
    echo "==================================================================="
    echo "1. Perform full backup (files + database)"
    echo "2. Perform database-only backup"
    echo "3. Perform incremental backup"
    echo "4. Set up scheduled backups"
    echo "5. Configure backup settings"
    echo "6. Clean up old backups"
    echo "7. Exit"
    echo "==================================================================="
    echo
    read -p "Enter your choice [1-7]: " choice

    case $choice in
    1)
        site=$(select_wordpress_site)
        if [ $? -eq 0 ] && check_wordpress "$site"; then
            full_backup "$site"
        fi
        read -p "Press Enter to continue..."
        show_menu
        ;;
    2)
        site=$(select_wordpress_site)
        if [ $? -eq 0 ] && check_wordpress "$site"; then
            # Fix for mysqldump deprecation warning
            export MYSQL_PWD="$(grep -oP "(?<=DB_PASSWORD', ')[^']+" /var/www/$site/wp-config.php)"
            db_backup "$site"
        fi
        read -p "Press Enter to continue..."
        show_menu
        ;;
    3)
        site=$(select_wordpress_site)
        if [ $? -eq 0 ] && check_wordpress "$site"; then
            incremental_backup "$site"
        fi
        read -p "Press Enter to continue..."
        show_menu
        ;;
    4)
        echo "Set up scheduled backups"
        echo "========================"
        site=$(select_wordpress_site)
        if [ $? -eq 0 ] && check_wordpress "$site"; then
            echo "Select backup type:"
            echo "1. Full backup"
            echo "2. Database-only backup"
            echo "3. Incremental backup"
            read -p "Enter your choice [1-3]: " backup_type_choice

            echo "Enter cron schedule (e.g., '0 2 * * *' for daily at 2 AM):"
            read -p "Schedule: " schedule

            case $backup_type_choice in
            1) setup_cron "$site" "full" "$schedule" ;;
            2) setup_cron "$site" "db" "$schedule" ;;
            3) setup_cron "$site" "incremental" "$schedule" ;;
            *) echo "Invalid choice" ;;
            esac
        fi
        read -p "Press Enter to continue..."
        show_menu
        ;;
    5)
        configure_settings
        read -p "Press Enter to continue..."
        show_menu
        ;;
    6)
        site=$(select_wordpress_site)
        if [ $? -eq 0 ] && check_wordpress "$site"; then
            cleanup_backups "$site"
        fi
        read -p "Press Enter to continue..."
        show_menu
        ;;
    7)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice"
        read -p "Press Enter to continue..."
        show_menu
        ;;
    esac
}

# Process command-line arguments
if [ $# -gt 0 ]; then
    case "$1" in
    --full)
        if [ -z "$2" ]; then
            log_message "ERROR: No domain specified for full backup"
            exit 1
        fi

        if check_wordpress "$2"; then
            full_backup "$2"
            cleanup_backups "$2"
        fi
        ;;
    --db)
        if [ -z "$2" ]; then
            log_message "ERROR: No domain specified for database backup"
            exit 1
        fi

        if check_wordpress "$2"; then
            # Fix for mysqldump deprecation warning
            export MYSQL_PWD="$(grep -oP "(?<=DB_PASSWORD', ')[^']+" /var/www/$2/wp-config.php)"
            db_backup "$2"
            cleanup_backups "$2"
        fi
        ;;
    --incremental)
        if [ -z "$2" ]; then
            log_message "ERROR: No domain specified for incremental backup"
            exit 1
        fi

        if check_wordpress "$2"; then
            incremental_backup "$2"
            cleanup_backups "$2"
        fi
        ;;
    --help)
        echo "Usage: $0 [OPTION] [DOMAIN]"
        echo
        echo "Options:"
        echo "  --full DOMAIN        Perform full backup for DOMAIN"
        echo "  --db DOMAIN          Perform database-only backup for DOMAIN"
        echo "  --incremental DOMAIN Perform incremental backup for DOMAIN"
        echo "  --help               Display this help message"
        echo
        echo "Without options, the script will display an interactive menu."
        exit 0
        ;;
    *)
        log_message "Unknown option: $1"
        log_message "Use --help for usage information"
        exit 1
        ;;
    esac
else
    # No arguments provided, show interactive menu
    show_menu
fi
