# AWS email feedback on bounce, complaint, delivery, open, and click

## Configuration sets

Create a configuration set which will be used on your verified domain/sender in AWS SES.

Do not use track of "open" and "click" events, as this is managed by the
nimletter itself.

![alt text](assets/screenshots/configuration_set_events.png)

![alt text](assets/screenshots/configuration_set_destination.png)


## SNS Topic

Input the domain `/webhook/incoming/sns/secret` to confirm the subscription (http or https).


# AWS HTTP endpoint

Create a AWS user with IAM policy to SendRawEmail. That will skip SMTP server and use the AWS SES HTTP endpoint directly.
