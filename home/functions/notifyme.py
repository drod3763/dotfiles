#!/usr/bin/env python3
# -*-coding: utf-8 -*-

import requests
import json
import sys

api_key = '<your NotifyMyDevice api key here>'
url = "https://www.notifymydevice.com/push"

def send_notification(title, message):
    data = {"ApiKey": api_key, "PushTitle": title,"PushText": message}
    headers = {'Content-Type': 'application/json'}
    r = requests.post(url, data=json.dumps(data), headers=headers)
    if r.status_code != 200:
        raise RuntimeError(r)


if __name__ == "__main__":
    notification_title = sys.argv[1]
    if ' '.join(sys.argv[2:]).strip():
        notification_message = ' '.join(sys.argv[2:])
    else:
        notification_message = 'done'

    try:
        send_notification(notification_title, notification_message)
    except RuntimeError as e:
        print(f'Error while sending notification: {e.args[0]}')
    else:
        print('Notification sent!')