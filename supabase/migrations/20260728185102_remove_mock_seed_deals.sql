-- Remove mock-catalog seed deals that used biz-* IDs (not chamber_members.cm_id).
-- Fresh installs should not rely on these rows; create real perks via admin / submissions.

delete from public.deals
where created_by = 'seed'
  and business_id in ('biz-001', 'biz-002', 'biz-003');
