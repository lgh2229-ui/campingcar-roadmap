import { withSupabase } from 'npm:@supabase/server'

const page = (message = '') => `<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>캠핑카족 로드맵 회원탈퇴 요청</title><style>body{font-family:system-ui,-apple-system,sans-serif;max-width:680px;margin:40px auto;padding:0 18px;line-height:1.6;color:#1f2937}h1{font-size:28px}label{display:block;margin:16px 0 6px;font-weight:700}input,textarea{width:100%;box-sizing:border-box;padding:12px;border:1px solid #cbd5e1;border-radius:10px;font-size:16px}button{margin-top:18px;padding:12px 18px;border:0;border-radius:10px;background:#1565c0;color:white;font-size:16px;font-weight:700}.note{background:#f1f5f9;padding:14px;border-radius:10px}.msg{background:#ecfdf5;padding:14px;border-radius:10px;color:#166534}.hp{position:absolute;left:-9999px}</style></head><body><h1>캠핑카족 로드맵 회원탈퇴 요청</h1><p class="note">앱에 로그인할 수 있다면 <b>내정보 → 회원탈퇴</b>에서 즉시 탈퇴할 수 있습니다. 로그인할 수 없는 경우 아래 양식으로 삭제 요청을 접수할 수 있습니다. 계정 보호를 위해 추가 본인확인을 요청할 수 있습니다.</p>${message ? `<p class="msg">${message}</p>` : ''}<form method="post"><label>아이디</label><input name="username" minlength="4" maxlength="20" pattern="[A-Za-z0-9_]{4,20}" required><label>휴대폰 번호</label><input name="phone" inputmode="tel" minlength="10" maxlength="20" required placeholder="01012345678"><label>추가 메모(선택)</label><textarea name="note" maxlength="500" rows="4"></textarea><input class="hp" name="website" tabindex="-1" autocomplete="off"><button type="submit">회원탈퇴 요청 접수</button></form><p style="margin-top:28px;font-size:14px;color:#64748b">탈퇴 처리 시 계정 및 앱 내 개인 데이터가 삭제됩니다. 법령상 보관 의무가 있는 정보는 해당 기간 동안 별도로 보관될 수 있습니다.</p></body></html>`

export default {
  fetch: withSupabase({ auth: 'none' }, async (req, ctx) => {
    if (req.method === 'GET') return new Response(page(), { headers: { 'content-type': 'text/html; charset=utf-8' } })
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 })
    const form = await req.formData()
    if ((form.get('website') ?? '').toString().trim()) return new Response(page('요청이 접수되었습니다.'), { headers: { 'content-type': 'text/html; charset=utf-8' } })
    const username = (form.get('username') ?? '').toString().trim()
    const phone = (form.get('phone') ?? '').toString().replace(/[^0-9+]/g, '')
    const note = (form.get('note') ?? '').toString().trim().slice(0, 500)
    if (!/^[A-Za-z0-9_]{4,20}$/.test(username) || phone.length < 10 || phone.length > 20) {
      return new Response(page('입력한 아이디 또는 휴대폰 번호를 확인해주세요.'), { status: 400, headers: { 'content-type': 'text/html; charset=utf-8' } })
    }
    const { error } = await ctx.supabaseAdmin.from('account_deletion_requests').insert({ username, phone, note })
    if (error) {
      console.error(error)
      return new Response(page('접수 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'), { status: 500, headers: { 'content-type': 'text/html; charset=utf-8' } })
    }
    return new Response(page('회원탈퇴 요청이 접수되었습니다. 본인확인 후 처리됩니다.'), { headers: { 'content-type': 'text/html; charset=utf-8' } })
  })
}
