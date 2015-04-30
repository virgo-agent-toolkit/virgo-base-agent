To generate a signature:

```sh
openssl dgst -sha256 -sign ../ca/server.key -out input1.txt.sig input1.txt
```

Use 1234 for the password.
