# lgtm[] suppression — 3-field comment template
#
# Copy the block above the offending line and put `# lgtm[py/<rule-id>]` at the
# end of the offending line itself.
#
# The 3 mandatory fields:
#   Reason — why this site is FP or unfixable, in plain words
#   Reviewer — who acknowledged this (you / the user) and when
#   Re-audit if — what condition, if changed, makes this suppression invalid

# ──────────── copy from here ────────────

# lgtm[py/<rule-id>]
#   Reason: <one-sentence why this isn't a real issue, OR why it can't be fixed>
#   Reviewer: <@username>  Date: <YYYY-MM-DD>
#   Re-audit if: <what change to this code would flip FP→TP and require re-evaluation>
target_line_of_code  # lgtm[py/<rule-id>]

# ──────────── illustrative examples ────────────
# (Generic patterns, not from any specific project — adapt to your context.)

# Example A: FP — value is encrypted ciphertext, CodeQL thinks plaintext
def handler(response, user):
    response.set_cookie(
        "session_blob",
        # lgtm[py/clear-text-storage-sensitive-data]
        #   Reason: the value is encrypted ciphertext written elsewhere
        #           (the plaintext never touches this code path). CodeQL
        #           flags due to the variable name pattern, not actual
        #           plaintext flow.
        #   Reviewer: @<reviewer>  Date: <YYYY-MM-DD>
        #   Re-audit if: the cookie value ever comes from a non-encrypted source
        str(user.encrypted_blob),  # lgtm[py/clear-text-storage-sensitive-data]
        httponly=True,
        secure=True,
    )

# Example B: TP-but-justified — bootstrap key, encryption impossible by design
def write_secret_to_file(path, value):
    # lgtm[py/clear-text-storage-sensitive-data]
    #   Reason: bootstrap path for master signing key — by construction
    #           cannot be encrypted at rest (no outer key to wrap it).
    #           Mitigation is OS-level: the next call sets owner-only
    #           permissions. Same pattern as ~/.ssh/id_rsa.
    #   Reviewer: @<reviewer>  Date: <YYYY-MM-DD>
    #   Re-audit if: a HSM / cloud-KMS option becomes a hard requirement
    path.write_text(value, encoding="utf-8")  # lgtm[py/clear-text-storage-sensitive-data]

# Example C: hash for indexed lookup, not password storage
import hashlib

def hash_token(token):
    """One-way SHA-256 hash for O(1) DB lookup index.

    Tokens are 256-bit random; brute-force is already infeasible regardless
    of hash function. Switching to bcrypt would (a) break the O(1) index
    (bcrypt output is salted per-call, not deterministic) and (b) add
    100-500ms per authenticated request.
    """
    # lgtm[py/weak-sensitive-data-hashing]
    #   Reason: this hash is a deterministic lookup index, not a password
    #           verifier. See docstring for why bcrypt/argon2 would actively
    #           break the system.
    #   Reviewer: @<reviewer>  Date: <YYYY-MM-DD>
    #   Re-audit if: token entropy source weakens below 128 bits
    return hashlib.sha256(token.encode()).hexdigest()  # lgtm[py/weak-sensitive-data-hashing]
