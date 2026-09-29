#!/usr/bin/env python3
"""Generate golden vectors for the MH signed entitlement token (mh1).

Format:  mh1.<b64url(payload_json)>.<b64url(RSASSA-PKCS1-v1_5 SHA-256 signature)>
The signature is computed over the ASCII bytes of the string "mh1.<b64url(payload_json)>".
This uses a TEST-ONLY key generated here. NEVER use it for production.

Usage: python3 make_golden.py OUT_DIR
Writes: test_public.pem, test_private_pkcs8.pem, golden.json
"""
import base64, json, sys, os
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives import hashes, serialization

def b64u(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()

def sign(priv, payload: dict) -> str:
    body = "mh1." + b64u(json.dumps(payload, separators=(",", ":"), sort_keys=True).encode())
    sig = priv.sign(body.encode(), padding.PKCS1v15(), hashes.SHA256())
    return body + "." + b64u(sig)

def main(out: str) -> None:
    os.makedirs(out, exist_ok=True)
    priv = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pub_pem = priv.public_key().public_bytes(
        serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo).decode()
    priv_pem = priv.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()).decode()
    good = {"v": 1, "pkg": "com.mulliganhills.game", "pid": "mh_full_unlock",
            "ord": "GPA.0000-0000-0000-00000", "pth": "0" * 16, "iat": 1790000000, "ref": 1797776000}
    tok = sign(priv, good)
    # tampered: change pid after signing
    parts = tok.split(".")
    bad_payload = dict(good); bad_payload["pid"] = "other_product"
    tampered = "mh1." + b64u(json.dumps(bad_payload, separators=(",", ":"), sort_keys=True).encode()) + "." + parts[2]
    with open(os.path.join(out, "test_public.pem"), "w") as f: f.write(pub_pem)
    with open(os.path.join(out, "test_private_pkcs8.pem"), "w") as f: f.write(priv_pem)
    with open(os.path.join(out, "golden.json"), "w") as f:
        json.dump({"valid": tok, "tampered": tampered, "expected_pid": "mh_full_unlock",
                   "expected_pkg": "com.mulliganhills.game"}, f, indent=2)
    print("wrote", out)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
