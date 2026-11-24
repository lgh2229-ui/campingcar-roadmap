import { createClient } from "npm:@supabase/supabase-js@2.49.10";

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json; charset=utf-8",
};
const json = (value: unknown, status = 200) => new Response(
  JSON.stringify(value), { status, headers },
);
const RADIUS = 1000;
const EARTH = 6371000;
const distance = (a: number, b: number, c: number, d: number) => {
  const rad = (x: number) => x * Math.PI / 180;
  const t = Math.sin(rad(c - a) / 2) ** 2
    + Math.cos(rad(a)) * Math.cos(rad(c))
    * Math.sin(rad(d - b) / 2) ** 2;
  return 2 * EARTH * Math.asin(Math.sqrt(Math.min(1, Math.max(0, t))));
};
type Spot = {
  name: string; category: string; address: string;
  latitude: number; longitude: number; distance_m: number;
  score: number | null; url: string;
  source: "kakao" | "curated" | "community" | "osm";
  comment?: string; kakao_id?: string;
};
function categoryLabel(source: string) {
  if (/카페|커피|coffee|디저트/i.test(source)) return "카페";
  if (/베이커리|빵집|제과|bakery/i.test(source)) return "베이커리";
  return "식당";
}
function tidy(s: string): string { return s.replace(/\s+/g, "").toLowerCase(); }
function isDuplicate(a: Spot, b: Spot): boolean {
  return (Boolean(a.kakao_id) && a.kakao_id === b.kakao_id)
      || (tidy(a.name) === tidy(b.name)
          && distance(a.latitude, a.longitude, b.latitude, b.longitude) < 130);
}
async function kakaoQuery(
  key: string, url: URL, timeoutMs = 4500,
): Promise<Record<string, unknown> | null> {
  const ctrl = new AbortController();
  const timeout = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const r = await fetch(url, {
      headers: { Authorization: "KakaoAK " + key },
      signal: ctrl.signal,
    });
    if (!r.ok) {
      console.error("Kakao local search HTTP", r.status);
      return null;
    }
    return await r.json();
  } catch (e) {
    console.error("Kakao local search failed:", String(e));
    return null;
  } finally {
    clearTimeout(timeout);
  }
}
function fromKakao(d: Record<string, unknown>, lat: number, lon: number): Spot | null {
  const latitude = Number(d.y), longitude = Number(d.x);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  const distance_m = Math.round(distance(lat, lon, latitude, longitude));
  if (distance_m > RADIUS) return null;
  const name = String(d.place_name ?? "").trim();
  if (name.length < 2) return null;
  const category = String(d.category_name ?? "");
  return {
    name, category: String(d.category_group_code ?? "") === "CE7"
      ? "카페" : categoryLabel(category),
    latitude, longitude,
    distance_m,
    address: String(d.road_address_name || d.address_name || ""),
    score: null,
    url: String(d.place_url || ""),
    source: "kakao",
    kakao_id: String(d.id || ""),
  };
}
async function discover(key: string, lat: number, lon: number) {
  // Kakao Local REST: FD6 restaurants + CE7 cafes. Three pages per group.
  // Cache the result so revisiting a place does not requery the provider.
  const pages = await Promise.all(
    ["FD6", "CE7"].flatMap((category_group_code) =>
      [1, 2, 3].map(async (page) => {
        const url = new URL("https://dapi.kakao.com/v2/local/search/category.json");
        url.search = new URLSearchParams({
          category_group_code,
          x: String(lon), y: String(lat), radius: String(RADIUS),
          page: String(page), size: "15", sort: "distance",
        }).toString();
        return await kakaoQuery(key, url);
      })
    ),
  );
  const raw = pages.flatMap((p) => Array.isArray(p?.documents) ? p.documents : []);
  const spots: Spot[] = [];
  for (const d of raw) {
    const item = fromKakao(d, lat, lon);
    if (item && !spots.some((x) => isDuplicate(x, item))) spots.push(item);
  }
  return { spots, provider_available: pages.some((p) => p !== null) };
}


/** OpenStreetMap fallback, used only when nearby provider results are sparse. */
async function osmDiscover(lat: number, lon: number): Promise<{
  spots: Spot[]; provider_available: boolean;
}> {
  const query = '[out:json][timeout:8];('
    + 'nwr(around:1000,' + lat + ',' + lon
    + ')["amenity"~"^(restaurant|cafe|fast_food|food_court)$"];'
    + 'nwr(around:1000,' + lat + ',' + lon
    + ')["shop"~"^(bakery|pastry)$"];'
    + ');out center tags;';
  const sites = [
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
  ];
  for (const base of sites) {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 6500);
    try {
      const response = await fetch(base + "?data=" + encodeURIComponent(query), {
        signal: ctrl.signal,
        headers: { "User-Agent": "CampingcarRoadmap/1.0" },
      });
      if (!response.ok) continue;
      const data = await response.json();
      if (!Array.isArray(data.elements)) continue;
      const spots: Spot[] = [];
      for (const el of data.elements) {
        const tags = el.tags ?? {};
        const name = String(tags["name:ko"] || tags.name || "").trim();
        if (name.length < 2) continue;
        const latitude = Number(el.lat ?? el.center?.lat);
        const longitude = Number(el.lon ?? el.center?.lon);
        if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) continue;
        const distance_m = Math.round(distance(lat, lon, latitude, longitude));
        if (distance_m > RADIUS) continue;
        const category = tags.shop === "bakery" || tags.shop === "pastry" ? "베이커리"
          : tags.amenity === "cafe" ? "카페" : "식당";
        const item: Spot = {
          name, category, latitude, longitude, distance_m,
          address: String(tags["addr:full"] || tags["addr:street"] || ""),
          score: null, source: "osm",
          url: "https://www.openstreetmap.org/" + el.type + "/" + el.id,
        };
        if (!spots.some((x) => isDuplicate(x, item))) spots.push(item);
      }
      return { spots, provider_available: true };
    } catch (e) {
      console.warn("OSM restaurant fallback:", String(e));
    } finally {
      clearTimeout(timer);
    }
  }
  return { spots: [], provider_available: false };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  try {
    const authorization = req.headers.get("authorization") ?? "";
    if (!authorization.startsWith("Bearer ")) return json({ error: "unauthorized" }, 401);
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const kakao = Deno.env.get("KAKAO_REST_API_KEY") ?? "";
    if (!supabaseUrl || !anon || !service) return json({ error: "server_configuration" }, 503);

    const userDb = createClient(supabaseUrl, anon, {
      global: { headers: { Authorization: authorization } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: who, error: authErr } = await userDb.auth.getUser();
    if (authErr || !who.user) return json({ error: "unauthorized" }, 401);
    const adminDb = createClient(supabaseUrl, service, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const body = await req.json().catch(() => ({}));
    const placeId = String(body.place_id ?? "");
    if (!/^[0-9a-f]{8}-[0-9a-f-]{27,36}$/i.test(placeId)) {
      return json({ error: "invalid_place" }, 400);
    }
    const { data: place, error: placeError } = await userDb.from("places")
      .select("id, latitude, longitude, approval_status")
      .eq("id", placeId).single();
    if (placeError || !place || place.approval_status !== "approved") {
      return json({ error: "place_not_found" }, 404);
    }
    const lat = Number(place.latitude), lon = Number(place.longitude);
    const mode = String(body.mode || "list");
    if (mode === "lookup") {
      const query = String(body.query ?? "").trim().slice(0, 80);
      if (query.length < 2) return json({ error: "query_too_short" }, 400);
      let spots: Spot[] = [];
      let providerAvailable = false;
      if (kakao) {
        const url = new URL("https://dapi.kakao.com/v2/local/search/keyword.json");
        url.search = new URLSearchParams({
          query, x: String(lon), y: String(lat),
          radius: "1000", size: "15", sort: "distance",
        }).toString();
        const data = await kakaoQuery(kakao, url);
        if (data) {
          providerAvailable = true;
          const raw = Array.isArray(data.documents) ? data.documents : [];
          spots = raw.filter((d) => ["FD6", "CE7"].includes(
            String(d.category_group_code || ""),
          )).map((d) => fromKakao(d, lat, lon)).filter(
            (x): x is Spot => x !== null,
          );
        }
      }
      if (!spots.length) {
        const osm = await osmDiscover(lat, lon);
        providerAvailable ||= osm.provider_available;
        const requested = tidy(query);
        spots = osm.spots.filter((x) => tidy(x.name).includes(requested)
          || requested.includes(tidy(x.name)));
      }
      if (!providerAvailable) return json({ error: "search_unavailable" }, 503);
      return json({ spots: spots.slice(0, 12) });
    }
    if (mode !== "list") return json({ error: "unknown_mode" }, 400);

    const { data: cached } = await adminDb.from("nearby_food_cache")
      .select("latitude,longitude,results,expires_at")
      .eq("place_id", placeId).maybeSingle();
    const isFresh = cached &&
      Math.abs(Number(cached.latitude) - lat) < 0.000001 &&
      Math.abs(Number(cached.longitude) - lon) < 0.000001 &&
      new Date(String(cached.expires_at)).getTime() > Date.now() &&
      Array.isArray(cached.results);
    let discovered: Spot[] = isFresh ? cached.results as Spot[] : [];
    let providerAvailable = Boolean(kakao);
    if (!isFresh) {
      const kakaoFound = kakao
        ? await discover(kakao, lat, lon)
        : { spots: [] as Spot[], provider_available: false };
      const osmFound = kakaoFound.spots.length < 20
        ? await osmDiscover(lat, lon)
        : { spots: [] as Spot[], provider_available: false };
      providerAvailable = kakaoFound.provider_available || osmFound.provider_available;
      if (providerAvailable) {
        discovered = [...kakaoFound.spots];
        for (const item of osmFound.spots) {
          if (!discovered.some((r) => isDuplicate(r, item))) discovered.push(item);
        }
        const now = Date.now();
        await adminDb.from("nearby_food_cache").upsert({
          place_id: placeId, latitude: lat, longitude: lon,
          results: discovered, fetched_at: new Date(now).toISOString(),
          expires_at: new Date(now + 7 * 24 * 60 * 60 * 1000).toISOString(),
        });
      } else if (Array.isArray(cached?.results)) {
        discovered = cached.results as Spot[];
      }
    }
    const { data: rated, error: ratedErr } = await userDb.rpc(
      "nearby_diningcode_top20", { p_lat: lat, p_lon: lon },
    );
    if (ratedErr) console.warn("curated_food_lookup", ratedErr.message);
    const scored: Spot[] = (Array.isArray(rated) ? rated : []).map((r) => ({
      name: String(r.name), category: String(r.category),
      address: String(r.address), latitude: Number(r.latitude),
      longitude: Number(r.longitude), distance_m: Number(r.distance_m),
      score: typeof r.diningcode_score === "number" ? r.diningcode_score : null,
      url: String(r.diningcode_url || ""), source: "curated" as const,
    }));
    const { data: recommendations, error: recError } = await userDb
      .from("food_recommendations")
      .select("name,category,address,latitude,longitude,comment")
      .eq("status", "approved")
      .gte("latitude", lat - 0.01).lte("latitude", lat + 0.01)
      .gte("longitude", lon - 0.012).lte("longitude", lon + 0.012)
      .limit(100);
    if (recError) console.warn("approved_food_lookup", recError.message);
    const community: Spot[] = (recommendations || []).map((r) => ({
      name: String(r.name), category: String(r.category),
      address: String(r.address), latitude: Number(r.latitude),
      longitude: Number(r.longitude),
      distance_m: Math.round(distance(lat, lon, Number(r.latitude), Number(r.longitude))),
      score: null, url: "", source: "community" as const,
      comment: String(r.comment || ""),
    })).filter((r) => r.distance_m <= RADIUS);

    const all: Spot[] = [];
    // Curated scores take precedence. A community-approved business is next,
    // then location-discovered spots, with no invented review scores.
    for (const source of [scored, community, discovered]) for (const item of source) {
      if (item.distance_m > RADIUS) continue;
      if (!all.some((r) => isDuplicate(r, item))) all.push(item);
    }
    all.sort((a, b) =>
      (b.score ?? -1) - (a.score ?? -1) ||
      (a.source === "community" ? -1 : 0) - (b.source === "community" ? -1 : 0) ||
      a.distance_m - b.distance_m ||
      a.name.localeCompare(b.name)
    );
    const top = all.slice(0, 20).map((r, i) => ({ ...r, rank: i + 1 }));
    return json({
      spots: top, radius_m: RADIUS, max_results: 20,
      source_status: providerAvailable ? "ok" : "partial",
      cache_hit: Boolean(isFresh),
    });
  } catch (e) {
    console.error("nearby-food:", String(e));
    return json({ error: "nearby_food_failed" }, 500);
  }
});
