-- Les tables de déduplication ne se lisent pas depuis le client.
-- Les compteurs publics vivent sur `courses` ; seuls les RPC y écrivent.

revoke all on table public.course_views from anon, authenticated, public;
revoke all on table public.course_adopts from anon, authenticated, public;
