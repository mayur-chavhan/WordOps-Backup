# Setting Up Notifications for WordPress Backups

This guide will walk you through the process of setting up different notification methods for your WordPress backups.

## Table of Contents

1. [Why Use Notifications for Backups](#why-use-notifications-for-backups)
2. [Telegram Notifications](#telegram-notifications)
3. [SMTP Email Notifications](#smtp-email-notifications)
4. [ntfy Notifications](#ntfy-notifications)
5. [Using Multiple Notification Methods](#using-multiple-notification-methods)
6. [Troubleshooting](#troubleshooting)

## Why Use Notifications for Backups

- **Real-time Alerts**: Get instant notifications when backups complete or fail
- **Detailed Information**: Receive comprehensive information about backup size, duration, and location
- **Monitoring**: Keep track of your backup history and ensure they're running as scheduled
- **Error Reporting**: Get notified immediately if something goes wrong
- **Peace of Mind**: Confirm that your critical WordPress data is being backed up properly

## Telegram Notifications

Telegram offers a convenient way to receive notifications on your mobile device or desktop.

### Step-by-Step Setup Guide

#### 1. Create a Telegram Bot

1. **Open Telegram** and search for "BotFather" in the search bar
   - BotFather is the official Telegram bot that allows you to create and manage bots

2. **Start a chat with BotFather** by clicking on it and pressing "Start"

3. **Create a new bot** by sending the command:
   ```
   /newbot
   ```

4. **Choose a name for your bot**
   - This is the display name that will appear in conversations
   - Example: `WordOps Backup Notifier`

5. **Choose a username for your bot**
   - This must end with "bot" and be unique
   - Example: `wordops_backup_bot` or `wp_backup_bot`

6. **Save your bot token**
   - BotFather will respond with a message containing your bot token
   - It looks like this: `123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ`
   - This token is used to authenticate your bot - keep it secure!

#### 2. Start a Conversation with Your Bot

1. **Search for your bot** by its username in the Telegram search bar
   - Example: `@wordops_backup_bot`

2. **Start a conversation** with your bot by clicking "Start"
   - This step is crucial as the bot can only send messages to users who have initiated a conversation with it

#### 3. Get Your Chat ID

There are two ways to get your Chat ID:

##### Method 1: Using the Telegram API

1. **Open your web browser** and enter the following URL, replacing `YOUR_BOT_TOKEN` with your actual bot token:
   ```
   https://api.telegram.org/botYOUR_BOT_TOKEN/getUpdates
   ```

2. **Send a message to your bot** in the Telegram app
   - Type any message like "Hello" and send it to your bot

3. **Refresh the browser page** with the API URL
   - You should see a JSON response containing information about your message

4. **Find your Chat ID** in the JSON response
   - Look for the `"chat":{"id":` field
   - The number after this field is your Chat ID
   - It might be a negative number if you're using a group chat

##### Method 2: Using a Chat ID Bot

1. **Search for "Get My ID" bot** or similar in Telegram
   - There are several bots that can tell you your Chat ID

2. **Start a chat with the ID bot** and follow its instructions
   - It will typically respond with your Chat ID immediately

#### 4. Configure the Backup Script

1. **Open the WordPress backup script** in a text editor

2. **Update the Telegram configuration** at the top of the file:
   ```bash
   # Notification settings
   ENABLE_NOTIFICATIONS=true
   NOTIFICATION_TYPE="telegram"
   
   # Telegram notification settings
   TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"  # Replace with your actual bot token
   TELEGRAM_CHAT_ID="YOUR_CHAT_ID"      # Replace with your actual Chat ID
   ```

#### 5. Test the Notifications

1. **Run the backup script** with a test backup:
   ```bash
   ./wordpress-backup.sh --db yourdomain.com
   ```

2. **Check your Telegram** for a notification
   - You should receive a detailed message about the backup

## SMTP Email Notifications

Email notifications are useful for keeping a record of backups in your inbox and can include log files as attachments.

### Step-by-Step Setup Guide

#### 1. Set Up an Email Account for Sending Notifications

You can use an existing email account or create a new one specifically for sending backup notifications. Many providers offer SMTP access:

- Gmail
- Outlook/Office 365
- Yahoo Mail
- Your hosting provider's email service

For security reasons, it's recommended to:
- Use an app-specific password if available (especially for Gmail)
- Consider creating a dedicated email account for this purpose

#### 2. Get Your SMTP Settings

You'll need the following information:

1. **SMTP Server Address and Port**
   - Gmail: `smtp.gmail.com:587`
   - Outlook: `smtp.office365.com:587`
   - Yahoo: `smtp.mail.yahoo.com:587`

2. **Username** (usually your email address)

3. **Password** (or app-specific password)

4. **From Email Address** (the address that will appear as the sender)

5. **To Email Address** (where you want to receive notifications)

#### 3. Configure the Backup Script

1. **Open the WordPress backup script** in a text editor

2. **Update the SMTP configuration** at the top of the file:
   ```bash
   # Notification settings
   ENABLE_NOTIFICATIONS=true
   NOTIFICATION_TYPE="smtp"
   
   # SMTP notification settings
   SMTP_SERVER="smtp.example.com:587"  # Replace with your SMTP server
   SMTP_USER="your_username"           # Replace with your username
   SMTP_PASSWORD="your_password"       # Replace with your password
   SMTP_FROM="sender@example.com"      # Replace with sender email
   SMTP_TO="recipient@example.com"     # Replace with recipient email
   SMTP_SUBJECT_PREFIX="[WordPress Backup]"
   ```

#### 4. Test the Notifications

1. **Run the backup script** with a test backup:
   ```bash
   ./wordpress-backup.sh --db yourdomain.com
   ```

2. **Check your email** for a notification
   - You should receive an email with details about the backup
   - The email will include the backup log as an attachment

#### 5. Gmail-Specific Setup

If you're using Gmail, you'll need to:

1. **Enable "Less secure app access"** or
2. **Use an App Password**:
   - Go to your Google Account > Security
   - Enable 2-Step Verification if not already enabled
   - Go to App passwords
   - Select "Mail" and "Other (Custom name)"
   - Enter a name like "WordPress Backup"
   - Use the generated 16-character password in your script

## ntfy Notifications

ntfy is a simple HTTP-based pub-sub notification service that's perfect for sending push notifications to your devices.

### Step-by-Step Setup Guide

#### 1. Choose an ntfy Server

You can use the public ntfy server at `https://ntfy.sh` or host your own.

#### 2. Create a Unique Topic

Choose a unique, hard-to-guess topic name for your notifications. This acts as a channel for your messages.

#### 3. Set Up the ntfy App (Optional but Recommended)

1. **Install the ntfy app** on your devices:
   - [Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
   - [iOS](https://apps.apple.com/us/app/ntfy/id1625396347)
   - [Desktop](https://ntfy.sh/app)

2. **Subscribe to your topic** in the app
   - Add a new subscription with your topic name
   - Use the server URL (default: `https://ntfy.sh`)

#### 4. Configure the Backup Script

1. **Open the WordPress backup script** in a text editor

2. **Update the ntfy configuration** at the top of the file:
   ```bash
   # Notification settings
   ENABLE_NOTIFICATIONS=true
   NOTIFICATION_TYPE="ntfy"
   
   # ntfy notification settings
   NTFY_URL="https://ntfy.sh"           # Default ntfy server
   NTFY_TOPIC="your_unique_topic"       # Replace with your topic
   NTFY_PRIORITY="default"              # Options: min, low, default, high, urgent
   NTFY_TAGS="floppy_disk"              # Emoji tags for notifications
   ```

#### 5. Test the Notifications

1. **Run the backup script** with a test backup:
   ```bash
   ./wordpress-backup.sh --db yourdomain.com
   ```

2. **Check your ntfy app** or visit `https://ntfy.sh/your_unique_topic` in a browser
   - You should receive a push notification with backup details

#### 6. ntfy Priority Levels

ntfy supports different priority levels that affect how notifications are displayed:

- `min`: No notification, only visible in the app
- `low`: Normal notification without sound
- `default`: Normal notification with sound
- `high`: High-priority notification with sound
- `urgent`: Urgent notification that bypasses Do Not Disturb mode

## Using Multiple Notification Methods

You can receive notifications through multiple channels simultaneously.

### Configuration

1. **Open the WordPress backup script** in a text editor

2. **Set the notification type to "all"**:
   ```bash
   # Notification settings
   ENABLE_NOTIFICATIONS=true
   NOTIFICATION_TYPE="all"
   ```

3. **Configure all notification methods** as described in the previous sections

4. **Test the notifications**:
   ```bash
   ./wordpress-backup.sh --db yourdomain.com
   ```

You should receive notifications through all configured channels.

## Troubleshooting

### Telegram Notifications

#### Not Receiving Messages

1. **Verify your bot token** is correct
2. **Confirm your Chat ID** is correct
3. **Make sure you've started a conversation** with your bot
4. **Check that notifications are enabled** in the script

#### Bot Not Responding

1. **Restart the bot** by sending `/start` to BotFather and selecting your bot
2. **Check if the bot is active** by sending a message to it
3. **Create a new bot** if the current one is unresponsive

### SMTP Email Notifications

#### Emails Not Being Sent

1. **Check your SMTP server and port** are correct
2. **Verify your username and password**
3. **Check for typos** in email addresses
4. **Try a different SMTP server** if available

#### Authentication Issues

1. **For Gmail**: Make sure you're using an App Password if 2FA is enabled
2. **For other providers**: Check if you need to enable "Less secure app access"
3. **Check if your email provider** has additional security measures

### ntfy Notifications

#### Notifications Not Appearing

1. **Check your topic name** for typos
2. **Verify the ntfy server URL** is correct
3. **Try accessing your topic** directly in a browser
4. **Check if the ntfy service** is operational

#### App Not Receiving Notifications

1. **Check your subscription** in the app
2. **Verify notification permissions** on your device
3. **Try unsubscribing and resubscribing** to the topic

### General Troubleshooting

1. **Check the script logs** for error messages
2. **Verify that `ENABLE_NOTIFICATIONS` is set to `true`**
3. **Try setting `NOTIFICATION_TYPE` to a specific method** to isolate the issue
4. **Check your internet connection**
5. **Temporarily disable any firewalls** that might be blocking outgoing connections
