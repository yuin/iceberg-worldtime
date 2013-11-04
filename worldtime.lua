local ibs = require("icebergsupport")
local script_path = ibs.join_path(ibs.CONFIG_DIR, "luamodule")
local script_data_dir = ibs.join_path(script_path, "worldtime")

--
-- icons taken from http://deleket.deviantart.com/art/Flag-Icons-157982523
--                  http://www.iconarchive.com/show/nuoveXT-icons-by-saki/Apps-world-clock-icon.html
--

local dow_names = {Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=0}

local function dow(y, m, d) -- {{{
  -- get day of week (0=Sun)
  local t = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4};
  y = y -((m < 3) and 1 or 0);
  return math.floor((y + y/4 - y/100 + y/400 + t[m] + d) % 7);
end
-- }}}

local function date_nth_dow(year, month, d_ow, nth_week) -- {{{
  -- get nth DOW day in the year-month
  if type(d_ow) == "string" then
    d_ow = dow_names[d_ow]
  end

  if nth_week == "last" then
    nth_week = 1
    if month == 12 then
      month = 1
      year = year + 1
    else
      month = month + 1
    end
  end

  local d = 1
  local fdow = dow(year,month,d)
  while fdow ~= d_ow do
    fdow = math.floor((fdow+1)%7)
    d = d + 1
  end
  d = d + (nth_week-1)*7;
  if nth_week == "last" then
    d = tonumber(os.date("%d", os.time({year=year,month=month,day=d}) - (3600*7)))
  end
  
  return d
end
-- }}}

local function is_dst(local_value, dst_start, dst_end) -- {{{
  local local_table = os.date("*t", local_now_table)
  local local_dst_start_value = os.time({year=local_table.year, month=dst_start[1], day = date_nth_dow(local_table.year, dst_start[1], dst_start[3], dst_start[2]), hour=dst_start[4], min=0, sec=0})
  local local_dst_end_value = os.time({year=local_table.year, month=dst_end[1], day = date_nth_dow(local_table.year, dst_end[1], dst_end[3], dst_end[2]), hour=dst_end[4], min=0, sec=0})

  if local_value >= local_dst_start_value and local_value <= local_dst_end_value then
    return true
  end
  if local_dst_end_value < local_dst_start_value then
    if local_value >= local_dst_start_value or local_value <= local_dst_end_value then
      return true
    end
  end
  return false
end -- }}}

-- timezones {{{
local timezones = {}
local tzstr = [[-12 Y
-11 X NUT SST
-10 W CKT HAST HST TAHT TKT
-9 V AKST GAMT GIT HADT HNY
-8 U AKDT CIST HAY HNP PST PT
-7 T HAP HNR MST PDT
-6 S EAST GALT HAR HNC MDT
-5 R CDT COT EASST ECT EST ET HAC HNE PET
-4 Q AST BOT CLT COST EDT FKT GYT HAE HNA PYT
-3 P ADT ART BRT CLST FKST GFT HAA PMST PYST SRT UYT WGT
-2 O BRST FNT PMDT UYST WGST
-1 N AZOT CVT EGT
0 Z EGST GMT UTC WET WT
1 A CET DFT WAT WEDT WEST
2 B CAT CEDT CEST EET SAST WAST
3 C EAT EEDT EEST IST IDT MSK
4 D AMT AZT GET GST KUYT MSD MUT RET SAMT SCT
5 E AMST AQTT AZST HMT MAWT MVT PKT TFT TJT TMT UZT YEKT
6 F ALMT BIOT BTT IOT KGT NOVT OMST YEKST
7 G CXT DAVT HOVT ICT KRAT NOVST OMSST THA WIB
8 H CST ACT AWST BDT BNT CAST HKT IRKT KRAST MYT PHT SGT ULAT WITA WST
9 I AWDT IRKST JST KST PWT TLT WDT WIT YAKT
10 K AEST ChST PGT VLAT YAKST YAPT
11 L AEDT LHDT MAGT NCT PONT SBT VLAST VUT
12 M ANAST ANAT FJT GILT MAGST MHT NZST PETST PETT TVT WFT
13 FJST NZDT
11.5 NFT
10.5 ACDT LHST
9.5 ACST
6.5 CCT MMT
5.75 NPT
5.5 SLT
4.5 AFT IRDT
3.5 IRST
-2.5 HAT NDT
-3.5 HNT NST NT
-4.5 HLV VET
-9.5 MART MIT]]

for i, line in ipairs(ibs.regex_split("\r?\n", Regex.NONE, tzstr)) do
  local parts = ibs.regex_split("\\s+", Regex.NONE, line)
  local offset = tonumber(table.remove(parts, 1)) * 3600
  for j, tzname in ipairs(parts) do
    timezones[tzname] = offset
  end
end
-- }}}

-- A List of cities that will be shown in this command.
-- dst_start and dst_end represent daylight saving summer time like the following:
--   dst_start = { 10, 1, "Sun", 2 }  # DST starts at 2 a.m. on the first Sunday of October.
--   dst_end = { 4, 1, "Sun", 3 }  # DST ends at 3 a.m. on the first Sunday of April.
local cities = {
  {name="New York, New York, United States",     tz="EST", dst_start={3,2,"Sun",2}, dst_end={11,1,"Sun",2}, icon = "us.png"},
  {name="Los Angeles, California, United States",tz="PST", dst_start={3,2,"Sun",2}, dst_end={11,1,"Sun",2}, icon = "us.png"},
  {name="Vancouver, British Columbia, Canada",   tz="PST", dst_start={3,2,"Sun",2}, dst_end={11,1,"Sun",2}, icon = "us.png"},
  {name="Rio de Janeiro, Rio de Janeiro, Brazil",tz="BRT", dst_start={10,3,"Sun",0},dst_end={2,3,"Sun",0},  icon = "br.png"},
  {name="Honolulu, Hawaii, United States",       tz="HAST",dst_start=nil,           dst_end=nil,            icon = "us.png"},
  {name="Sydney, New South Wales, Australia",    tz="AEST",dst_start={10,1,"Sun",2},dst_end={4,1,"Sun",3},  icon = "au.png"},
  {name="Tokyo, Japan",                          tz="JST", dst_start=nil,           dst_end=nil,            icon = "jp.png"},
  {name="Beijing, China",                        tz="CST", dst_start=nil,           dst_end=nil,            icon = "cn.png"},
  {name="Singapore, Singapore",                  tz="SGT", dst_start=nil,           dst_end=nil,            icon = "sg.png"},
  {name="Delhi, Delhi, India",                   tz="IST", dst_start=nil,           dst_end=nil,            icon = "in.png"},
  {name="Moscow, Russia",                        tz="MSK", dst_start=nil,           dst_end=nil,            icon = "ru.png"},
  {name="Cairo, Egypt",                          tz="EET", dst_start=nil,           dst_end=nil,            icon = "eg.png"},
  {name="Cape Town, South Africa",               tz="SAST",dst_start=nil,           dst_end=nil,            icon = "za.png"},
  {name="Paris, France",               tz="CET", dst_start={3,"last","Sun",2},dst_end={10,"last","Sun",2},  icon = "fr.png"},
  {name="London, England, United Kingdom",tz="GMT", dst_start={3,"last","Sun",1},dst_end={10,"last","Sun",1},  icon = "uk.png"}
}

commands["worldtime"] = { 
  path = function(args) 
    if #args == 0 then return end
    ibs.set_clipboard(args[1])
  end, 
  completion = function(values)
    local candidates = {}
    local utc_now_table = os.date("!*t", os.time())
    -- utc_now_table = {year=2013, month=11, day=3, hour=7, min=00, sec=00}
    local utc_now_value = os.time(utc_now_table)
    for i, data in ipairs(cities) do
      local local_value = utc_now_value + timezones[data["tz"]]
      local local_table = os.date("*t", local_value)
      local dst = false
      if data.dst_start and is_dst(local_value, data.dst_start, data.dst_end) then
        local_value = local_value + 3600
        dst = true
      end
      local datetime = string.format("%s, %s", os.date("%Y-%m-%d %H:%M:%S", local_value), ibs.regex_split(",", Regex.NONE, data["name"])[1])
      local description = data["name"]
      if dst then
        description = string.format("%s %s", description, "DST")
      end
      table.insert(candidates, { value = datetime, description = description, icon=ibs.join_path(script_data_dir, data.icon)})
    end
    return candidates
  end,
  description = "shows current time at cities in the world",
  icon = ibs.join_path(script_data_dir, "app.png"),
  history=false
}
