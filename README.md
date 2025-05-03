# WordOps | WordPress Backup Script

A comprehensive backup solution for WordPress sites managed with WordOps. This script provides an easy-to-use interface for creating, managing, and scheduling backups with advanced features like incremental backups, compression options, and multiple notification methods.

![Version](https://img.shields.io/badge/version-1.1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Multiple Backup Types**:

  - Full backup (files + database)
  - Database-only backup
  - Incremental backup (only changed files since last full backup)
  - Restore functionality for all backup types

- **Advanced Compression**:

  - zstd compression support (better compression ratio and speed)
  - pigz support for parallel gzip compression on multi-core systems
  - Configurable compression levels

- **Backup Management**:

  - Configurable retention period
  - Automatic cleanup of old backups
  - Scheduled backups via cron
  - Batch operations for all sites at once

- **Multiple Notification Methods**:

  - Telegram notifications with rich formatting
  - Email notifications via SMTP with log attachment
  - ntfy notifications for simple push notifications
  - Detailed backup information (size, duration, timing)
  - Rich formatting with emojis

- **User-Friendly Interface**:
  - Interactive menu system
  - Command-line interface for automation
  - Detailed logging
  - Backup restore functionality with multiple options

## Requirements

- WordOps WordPress installation
- Bash shell
- Optional: zstd for better compression
- Optional: pigz for parallel gzip compression
- Optional: Notification services (Telegram, SMTP, ntfy)

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/mayur-chavhan/WordOps-Backup.git
   cd WordOps-Backup
   ```

2. Make the script executable:

   ```bash
   chmod +x wordpress-backup.sh
   ```

3. Configure the script by editing the variables at the top of the file (see Configuration section below).

4. For notification setup, follow the instructions in the Configuration section.

## Usage

### Interactive Mode

Run the script without arguments to use the interactive menu:

```bash
./wordpress-backup.sh
```

This will display a menu with the following options:

1. Perform full backup (files + database)
2. Perform database-only backup
3. Perform incremental backup
4. Set up scheduled backups
5. Configure backup settings
6. Clean up old backups
7. Restore backup
8. Exit

### Command-Line Mode

For automation or scripting, you can use the command-line interface:

```bash
# Full backup
./wordpress-backup.sh --full yourdomain.com

# Database-only backup
./wordpress-backup.sh --db yourdomain.com

# Incremental backup
./wordpress-backup.sh --incremental yourdomain.com

# Display help
./wordpress-backup.sh --help

# Restore a full backup
./wordpress-backup.sh --restore-full yourdomain.com backup_id

# Restore a database backup
./wordpress-backup.sh --restore-db yourdomain.com backup_id

# Restore an incremental backup
./wordpress-backup.sh --restore-inc yourdomain.com backup_id

# List available backups
./wordpress-backup.sh --list-backups yourdomain.com

# Clean up old backups for all sites
./wordpress-backup.sh --cleanup-all

# Schedule full backups for all sites
./wordpress-backup.sh --schedule-full-all "0 2 * * *"
```

## Configuration

The script can be configured by editing the variables at the top of the file:

```bash
# Backup settings
DEFAULT_BACKUP_DIR="$HOME/wordpress_backups"
DEFAULT_RETENTION_DAYS=30
DEFAULT_COMPRESSION="zstd"  # Options: gzip, zstd
DEFAULT_COMPRESSION_LEVEL=3 # 1-19 for zstd, 1-9 for gzip/pigz

# Notification settings
ENABLE_NOTIFICATIONS=true
NOTIFICATION_TYPE="telegram" # Options: telegram, smtp, ntfy, all, none

# Telegram notification settings
TELEGRAM_BOT_TOKEN="" # Your Telegram bot token
TELEGRAM_CHAT_ID=""   # Your Telegram chat ID

# SMTP notification settings
SMTP_SERVER=""        # SMTP server address (e.g., smtp.gmail.com:587)
SMTP_USER=""          # SMTP username
SMTP_PASSWORD=""      # SMTP password
SMTP_FROM=""          # From email address
SMTP_TO=""            # To email address
SMTP_SUBJECT_PREFIX="[WordPress Backup]" # Email subject prefix

# ntfy notification settings
NTFY_URL="https://ntfy.sh" # ntfy server URL
NTFY_TOPIC=""              # Your ntfy topic
NTFY_PRIORITY="default"    # Options: min, low, default, high, urgent
NTFY_TAGS="floppy_disk"    # Emoji tags for notifications

# System settings
LOG_FILE="$HOME/wordpress_backups/backup.log"
PARALLEL_COMPRESSION=true # Use pigz for parallel gzip compression if available
```

### Configuration Options

| Option                      | Description                                                                  |
| --------------------------- | ---------------------------------------------------------------------------- |
| `DEFAULT_BACKUP_DIR`        | Directory where backups will be stored (defaults to $HOME/wordpress_backups) |
| `DEFAULT_RETENTION_DAYS`    | Number of days to keep backups before automatic cleanup                      |
| `DEFAULT_COMPRESSION`       | Compression method to use (zstd or gzip)                                     |
| `DEFAULT_COMPRESSION_LEVEL` | Compression level (higher = better compression but slower)                   |
| `ENABLE_NOTIFICATIONS`      | Enable or disable notifications                                              |
| `NOTIFICATION_TYPE`         | Type of notification to use (telegram, smtp, ntfy, all, none)                |
| `TELEGRAM_BOT_TOKEN`        | Your Telegram bot token                                                      |
| `TELEGRAM_CHAT_ID`          | Your Telegram chat ID for receiving notifications                            |
| `SMTP_SERVER`               | SMTP server address with port (e.g., smtp.gmail.com:587)                     |
| `SMTP_USER`                 | SMTP username                                                                |
| `SMTP_PASSWORD`             | SMTP password                                                                |
| `SMTP_FROM`                 | From email address                                                           |
| `SMTP_TO`                   | To email address                                                             |
| `SMTP_SUBJECT_PREFIX`       | Prefix for email subject                                                     |
| `NTFY_URL`                  | ntfy server URL (default: https://ntfy.sh)                                   |
| `NTFY_TOPIC`                | Your ntfy topic                                                              |
| `NTFY_PRIORITY`             | Priority for ntfy notifications                                              |
| `NTFY_TAGS`                 | Emoji tags for ntfy notifications                                            |
| `LOG_FILE`                  | Path to the log file                                                         |
| `PARALLEL_COMPRESSION`      | Use pigz for parallel compression if available                               |

## Backup Structure

Backups are organized in the following structure:

```
~/wordpress_backups/
├── example.com/
│   ├── 202401010000/                  # Full backup (timestamp)
│   │   ├── 202401010000-example.com-files.tar.zst
│   │   ├── 202401010000-example.com.sql.zst
│   │   └── wp-config.php
│   ├── 202401020000-db/               # DB-only backup
│   │   ├── 202401020000-example.com.sql.zst
│   │   └── wp-config.php
│   └── incremental/
│       └── 202401030000/              # Incremental backup
│           ├── 202401030000-example.com-incremental.tar.zst
│           ├── 202401030000-example.com.sql.zst
│           ├── changed_files.txt
│           └── wp-config.php
```

## Notification Setup

### Telegram

1. Create a Telegram bot using BotFather
2. Get your bot token and chat ID
3. Set the following variables in the script:
   ```bash
   NOTIFICATION_TYPE="telegram"
   TELEGRAM_BOT_TOKEN="your_bot_token"
   TELEGRAM_CHAT_ID="your_chat_id"
   ```

### SMTP (Email)

1. Set up an email account with SMTP access
2. Set the following variables in the script:
   ```bash
   NOTIFICATION_TYPE="smtp"
   SMTP_SERVER="smtp.example.com:587"
   SMTP_USER="your_username"
   SMTP_PASSWORD="your_password"
   SMTP_FROM="sender@example.com"
   SMTP_TO="recipient@example.com"
   SMTP_SUBJECT_PREFIX="[WordPress Backup]"
   ```

### ntfy

1. Choose an ntfy server (default is https://ntfy.sh)
2. Create a unique topic name
3. Set the following variables in the script:
   ```bash
   NOTIFICATION_TYPE="ntfy"
   NTFY_URL="https://ntfy.sh"
   NTFY_TOPIC="your_unique_topic"
   NTFY_PRIORITY="default"
   NTFY_TAGS="floppy_disk"
   ```

## Scheduling Backups

You can set up scheduled backups using the interactive menu or by manually adding cron jobs:

```bash
# Example: Daily full backup at 2 AM
0 2 * * * /path/to/wordpress-backup.sh --full example.com

# Example: Weekly database backup on Sundays at 3 AM
0 3 * * 0 /path/to/wordpress-backup.sh --db example.com

# Example: Daily incremental backup at 4 AM
0 4 * * * /path/to/wordpress-backup.sh --incremental example.com
```

## Customization and Development

The script is designed to be easily customizable and extensible. Here are some key components:

### Functions

- `full_backup()`: Performs a full backup (files + database)
- `db_backup()`: Performs a database-only backup
- `incremental_backup()`: Performs an incremental backup
- `cleanup_backups()`: Removes old backups based on retention period
- `setup_cron()`: Sets up scheduled backups
- `send_notification()`: Main notification function
- `send_telegram_notification()`: Sends Telegram notifications
- `send_smtp_notification()`: Sends email notifications
- `send_ntfy_notification()`: Sends ntfy notifications
- `format_duration()`: Formats time duration in human-readable format
- `format_size()`: Formats file size in human-readable format

## Troubleshooting

### Common Issues

- **Permission Denied**: Make sure the script is executable (`chmod +x wordpress-backup.sh`)
- **Backup Directory Not Found**: Ensure the backup directory exists and is writable
- **Compression Tool Not Found**: Install zstd or pigz if you want to use these compression methods
- **Notifications Not Working**: Verify your notification settings are correct

### Logs

Check the log file (default: `$HOME/wordpress_backups/backup.log`) for detailed information about backup operations and any errors.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Changelog

- **1.1.0** (Current)

  - Added comprehensive restore functionality for all backup types
  - Added batch operations for all sites at once
  - Improved site selection in all menu options
  - Added command-line options for restore operations
  - Added command-line options for scheduling backups for all sites
  - Added command-line options for cleaning up all sites
  - Fixed database restore to use wp-cli instead of direct MySQL commands
  - Enhanced error handling and reporting

- **1.0.0** (Initial Release)
  - Full, database-only, and incremental backup support
  - Multiple notification methods
  - Configurable compression options
  - Scheduled backups via cron
  - Automatic cleanup of old backups

## Author & Version

- **Author**: Mayur Chavhan - [GitHub](https://github.com/mayur-chavhan)
- **Version**: 1.1.0

## Acknowledgments

- [WordOps](https://wordops.net/) for the excellent WordPress server management tool
- [zstd](https://github.com/facebook/zstd) for the compression algorithm
- [pigz](https://zlib.net/pigz/) for parallel gzip implementation
- [ntfy](https://ntfy.sh/) for the simple notification service
