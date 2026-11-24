-- Source snapshot curated 2026-11-24. Reverify schedules/score periodically.
-- Data references: corresponding DiningCode profile URLs. Exact 1km radius
-- is calculated by the nearby-food Edge Function at runtime.
insert into public.diningcode_restaurants
(name,category,latitude,longitude,address,diningcode_score,diningcode_url,opening_hours,hours_source_url,hours_checked_at,checked_at)
values
('카페이앙','카페',36.6365273076962,126.799350613658,'충남 예산군 응봉면 예당관광로 146',71,'https://www.diningcode.com/profile.php?rid=TJ5sgYUvbN58','Tu-Su 10:00-18:00; Mo off','https://www.diningcode.com/profile.php?rid=TJ5sgYUvbN58','2026-11-24 18:00:00+09'::timestamptz,'2026-11-24 18:00:00+09'::timestamptz),
('해월','카페',36.6333114296868,126.792670478043,'충남 예산군 응봉면 예당관광로 61',70,'https://www.diningcode.com/profile.php?rid=lBI3OSynIodB','Tu-Fr 11:00-20:00; Sa-Su 11:00-21:00; Mo off','https://www.diningcode.com/profile.php?rid=lBI3OSynIodB','2026-11-24 18:00:00+09'::timestamptz,'2026-11-24 18:00:00+09'::timestamptz),
('오붓이카페','카페',36.6331000372653,126.797075227905,'충남 예산군 응봉면 예당관광로 100',65,'https://www.diningcode.com/profile.php?rid=mcppyyePLBgv','Tu-Su 10:00-18:30; Mo off','https://www.diningcode.com/profile.php?rid=mcppyyePLBgv','2026-11-24 18:00:00+09'::timestamptz,'2026-11-24 18:00:00+09'::timestamptz),
('예당전망대카페','카페',36.6388773826335,126.800909972109,'충남 예산군 응봉면 예당관광로 180',62,'https://www.diningcode.com/profile.php?rid=6OAuDmUhBiNg','Mo-Fr 10:30-21:00; Sa-Su 10:00-21:30','https://www.diningcode.com/profile.php?rid=6OAuDmUhBiNg','2026-11-24 18:00:00+09'::timestamptz,'2026-11-24 18:00:00+09'::timestamptz),
('우성가든','식당',36.6421314852663,126.805334252258,'충남 예산군 응봉면 예당관광로 265',61,'https://www.diningcode.com/profile.php?rid=FaJmaR4HTeTM','Mo-Su 09:00-20:00','https://www.diningcode.com/profile.php?rid=FaJmaR4HTeTM','2026-11-24 18:00:00+09'::timestamptz,'2026-11-24 18:00:00+09'::timestamptz),
('민물나라','식당',36.6336747580212,126.790194019983,'충남 예산군 응봉면 예당관광로 37',61,'https://www.diningcode.com/profile.php?rid=xyW8sRkBzzpS','Th-Tu 11:00-15:00,16:00-19:00; We off','https://www.diningcode.com/profile.php?rid=xyW8sRkBzzpS','2026-11-24 18:00:00+09'::timestamptz,'2026-11-24 18:00:00+09'::timestamptz),
('예당호수카페','카페',36.6379055080182,126.8001029203,'충남 예산군 응봉면 예당관광로 164',60,'https://www.diningcode.com/profile.php?rid=IUfopX5FLcJU','Mo-Su 10:00-19:00','https://www.diningcode.com/profile.php?rid=IUfopX5FLcJU','2026-11-24 18:00:00+09'::timestamptz,'2026-11-24 18:00:00+09'::timestamptz),
('돌고래회관','식당',36.6392335389057,126.801034292463,'충남 예산군 응봉면 예당관광로 180',50,'https://www.diningcode.com/profile.php?rid=a3HHk4Cu2Grf','Mo-Su 10:00-20:00','https://www.diningcode.com/profile.php?rid=a3HHk4Cu2Grf','2026-11-24 18:00:00+09'::timestamptz,'2026-11-24 18:00:00+09'::timestamptz),
('예촌사랑','식당',36.6412433045328,126.799560908208,'충남 예산군 응봉면 예당관광로 205',40,'https://www.diningcode.com/profile.php?rid=mGiVqJUUlLqf','Mo-Tu,Th-Su 11:00-21:00; We off','https://www.diningcode.com/profile.php?rid=mGiVqJUUlLqf','2026-11-24 18:00:00+09'::timestamptz,'2026-11-24 18:00:00+09'::timestamptz),
('예가민물매운탕','식당',36.6332011356403,126.789895653676,'충남 예산군 응봉면 예당관광로 31',NULL,'https://www.diningcode.com/profile.php?rid=gjj0tOgMETX7','Mo-Su 10:00-21:00','https://www.diningcode.com/profile.php?rid=gjj0tOgMETX7','2026-11-24 18:00:00+09'::timestamptz,'2026-11-24 18:00:00+09'::timestamptz)
on conflict(diningcode_url) do update set
  name=excluded.name,category=excluded.category,
  latitude=excluded.latitude,longitude=excluded.longitude,
  address=excluded.address,diningcode_score=excluded.diningcode_score,
  opening_hours=excluded.opening_hours,hours_source_url=excluded.hours_source_url,
  hours_checked_at=excluded.hours_checked_at,checked_at=excluded.checked_at,
  active=true;
