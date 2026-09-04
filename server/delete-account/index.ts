import { withSupabase } from 'npm:@supabase/server'

export default {
  fetch: withSupabase({ auth: 'user' }, async (_req, ctx) => {
    try {
      const userId = ctx.jwtClaims?.sub
      if (!userId) return Response.json({ ok: false, error: 'unauthorized' }, { status: 401 })
      const { data: rows, error: rowsError } = await ctx.supabaseAdmin.from('place_photos').select('storage_path').eq('uploader_id', userId)
      if (rowsError) throw rowsError
      const paths = (rows ?? []).map((row: { storage_path?: string }) => row.storage_path).filter((v: string | undefined): v is string => Boolean(v))
      if (paths.length > 0) {
        const { error: storageError } = await ctx.supabaseAdmin.storage.from('place-photos').remove(paths)
        if (storageError) throw storageError
      }
      const { error: deleteError } = await ctx.supabaseAdmin.auth.admin.deleteUser(userId)
      if (deleteError) throw deleteError
      return Response.json({ ok: true })
    } catch (error) {
      console.error('delete-account failed', error)
      return Response.json({ ok: false, error: error instanceof Error ? error.message : 'unknown_error' }, { status: 500 })
    }
  }),
}
