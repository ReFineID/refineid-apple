# Portrait QR stamp

The round PDF stamp contains one QR alphanumeric string:

```text
RID1/<SATU>/<UNIX-SECONDS>/<FILENAME>/<CERT-ID>/<BASE45-SIGNATURE>
```

The card signs exactly the UTF-8 bytes before `<CERT-ID>`:

```text
RID1/<SATU>/<UNIX-SECONDS>/<FILENAME>
```

There is no newline. `FILENAME` is an uppercase, ASCII-safe leaf name limited
to 48 characters. `CERT-ID` is the first 12 uppercase hexadecimal characters
of SHA-256 over the signer's DER certificate. The final field is the raw card
signature encoded with [RFC 9285 Base45](https://www.rfc-editor.org/rfc/rfc9285.html).
Because slash belongs to the Base45 alphabet, split only the first five slashes;
the remainder is the signature field.

## Offline verification

Obtain the qualified-signature certificate through the PDF CMS, the card, or a
separate certificate source. Check that its DER SHA-256 prefix equals
`CERT-ID`, Base45-decode the final field into `signature.der`, and save the
exact first four fields into `claim.txt` without a trailing newline. Then:

```sh
openssl x509 -inform DER -in signer.der -pubkey -noout > signer-public.pem
openssl dgst -sha384 \
  -verify signer-public.pem \
  -signature signature.der \
  claim.txt
```

`Verified OK` authenticates the compact claim. It does not bind the PDF bytes:
the PDF's separate PAdES signature does that. The current portrait-first
rendering omits the standard quiet zone and is not reliably detected by generic
camera readers. It is a visual checkpoint, not third-party assurance.
