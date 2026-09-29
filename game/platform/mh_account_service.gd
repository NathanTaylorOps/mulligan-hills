class_name MHAccountService
extends Node
## INTERFACE for the optional Supabase account (cloud saves / sharing). NOT required to play or to keep the unlock.
## Play Store policy requires in-app account deletion when accounts can be created in-app (verify current wording:
## https://support.google.com/googleplay/android-developer/answer/13327111 , UNVERIFIED) and Apple requires it too.
## Deleting the account never revokes the purchase (entitlement is bound to the store account).

signal account_deleted(success: bool, message: String)

func is_signed_in() -> bool:
	return false

## Server-side deletion is owned by the backend workstream; this hook must call it, then call
## MHPlatform.on_account_deleted(...) to reset local entitlement/analytics state as appropriate.
func request_account_deletion() -> void:
	account_deleted.emit(false, "not implemented")
