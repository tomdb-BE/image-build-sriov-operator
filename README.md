# image-build-sriov-operator

To use the webhook, certificates are required. Note that the webhook manifest expects:

```
Volumes:
  tls:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  operator-webhook-service
    Optional:    false
```

When doing this manually, the secret must be created using:

```
k create secret tls operator-webhook-service -n sriov-network-operator --cert=$WEBHOOK_CERT --key=$WEBHOOK_KEY
```

Where the WEBHOOK_CERT is signed by a kube-api-known CA authority. When doing this manually, we can provide the CA certificate to kube-api as caBundle via:

* sriov-operator-webhook-config (kind: ValidatingWebhookConfiguration)
* sriov-operator-webhook-config (kind: MutatingWebhookConfiguration)

For more information ==> https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#configure-admission-webhooks-on-the-fly

Note that by default the webhooks are disabled
