import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0";

const GOOGLE_AI_API_KEY = Deno.env.get("GOOGLE_AI_API_KEY");
const GOOGLE_AI_MODEL = Deno.env.get("GOOGLE_AI_MODEL") || "gemini-2.5-flash";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Haversine distance function in meters
function haversineDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371e3; // Earth radius in meters
  const toRad = (value: number) => (value * Math.PI) / 180;
  const phi1 = toRad(lat1);
  const phi2 = toRad(lat2);
  const deltaPhi = toRad(lat2 - lat1);
  const deltaLambda = toRad(lon2 - lon1);

  const a = Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
            Math.cos(phi1) * Math.cos(phi2) *
            Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

function isValidCoordinate(lat: number, lon: number): boolean {
  if (lat == null || lon == null) return false;
  if (lat < -90 || lat > 90) return false;
  if (lon < -180 || lon > 180) return false;
  return true;
}

function calculateRiskLevel(events: any[], maxVibration: number, confidence: string = 'high'): string {
  if (confidence === 'low' && events.length === 0) return 'not_assessed';

  const hasSevere = events.some((e) => e.event_type === 'severe_pothole');
  const hasPothole = events.some((e) => e.event_type === 'pothole');
  const hasDamaged = events.some((e) => e.event_type === 'damaged_road');
  
  if (hasSevere || (maxVibration >= 8.0 && events.length > 1)) {
    return 'critical';
  }
  if (hasPothole || (maxVibration >= 5.0 && events.length > 0)) {
    return 'high';
  }
  if (hasDamaged || (maxVibration >= 3.0 && events.length > 0)) {
    return 'medium';
  }
  if (events.length === 0 && confidence !== 'low') {
      return 'low';
  }
  return 'low';
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace("Bearer ", "");

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    );

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser(token);

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized: " + (userError?.message || 'No user') }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { session_id } = await req.json();

    if (!session_id) {
      return new Response(
        JSON.stringify({ error: "Missing session_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    
    // 1. Fetch Session Data
    const { data: sessionData, error: sessionError } = await supabaseClient
      .from("road_sessions")
      .select("id, title, start_time, end_time")
      .eq("id", session_id)
      .eq("user_id", user.id)
      .single();

    if (sessionError || !sessionData) {
      return new Response(
        JSON.stringify({ error: "Session not found or access denied" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Fetch Readings and Events safely via RLS
    const { data: readings, error: readingsError } = await supabaseClient
      .from("road_readings")
      .select("*")
      .eq("session_id", session_id)
      .order("recorded_at", { ascending: true });

    if (readingsError) {
      throw new Error("Failed to fetch road_readings: " + readingsError.message);
    }

    const { data: events, error: eventsError } = await supabaseClient
      .from("road_events")
      .select("*")
      .eq("session_id", session_id)
      .order("recorded_at", { ascending: true });

    if (eventsError) {
      throw new Error("Failed to fetch road_events: " + eventsError.message);
    }

    const { data: photos, error: photosError } = await supabaseClient
      .from("road_photos")
      .select("*")
      .eq("session_id", session_id)
      .order("taken_at", { ascending: true });

    if (photosError) {
      console.warn("Failed to fetch road_photos: " + photosError.message);
    }

    const { data: segmentAnalyses, error: segmentError } = await supabaseClient
      .from("road_segment_analyses")
      .select("*")
      .eq("session_id", session_id)
      .order("segment_index", { ascending: true });

    if (segmentError) {
      console.warn("Failed to fetch road_segment_analyses: " + segmentError.message);
    }

    // 3. Aggregate Data Server-Side
    let input_summary: any = { error: 'No readings available to analyze.' };
    
    if (readings && readings.length > 0) {
      const startTime = new Date(readings[0].recorded_at);
      const endTime = new Date(readings[readings.length - 1].recorded_at);
      const durationInSeconds = Math.floor((endTime.getTime() - startTime.getTime()) / 1000);

      let totalDistanceMeters = 0.0;
      let maxSpeed = 0.0;
      let sumSpeed = 0.0;
      let maxVibration = 0.0;
      let sumVibration = 0.0;
      let sumGpsAccuracy = 0.0;
      let minGpsAccuracy = 9999.0;
      let maxGpsAccuracy = 0.0;

      for (let i = 0; i < readings.length; i++) {
        const r = readings[i];
        if (r.speed > maxSpeed) maxSpeed = r.speed;
        sumSpeed += r.speed;
        
        if (r.vibration > maxVibration) maxVibration = r.vibration;
        sumVibration += r.vibration;
        
        sumGpsAccuracy += r.gps_accuracy;
        if (r.gps_accuracy < minGpsAccuracy) minGpsAccuracy = r.gps_accuracy;
        if (r.gps_accuracy > maxGpsAccuracy) maxGpsAccuracy = r.gps_accuracy;
        
        if (i > 0) {
          const prev = readings[i - 1];
          if (isValidCoordinate(prev.latitude, prev.longitude) && isValidCoordinate(r.latitude, r.longitude)) {
            totalDistanceMeters += haversineDistance(prev.latitude, prev.longitude, r.latitude, r.longitude);
          }
        }
      }

      if (minGpsAccuracy === 9999.0) minGpsAccuracy = 0.0;

      const count = readings.length;
      const avgSpeed = sumSpeed / count;
      const avgVibration = sumVibration / count;
      const avgGpsAccuracy = sumGpsAccuracy / count;

      let damagedRoadCount = 0;
      let potholeCount = 0;
      let severePotholeCount = 0;
      
      const eventsList = events || [];
      const eventDetails = [];
      for (const e of eventsList) {
        if (e.event_type === 'damaged_road') damagedRoadCount++;
        else if (e.event_type === 'pothole') potholeCount++;
        else if (e.event_type === 'severe_pothole') severePotholeCount++;

        eventDetails.push({
          recorded_at: e.recorded_at,
          latitude: e.latitude,
          longitude: e.longitude,
          event_type: e.event_type,
          severity: e.severity,
          vibration: e.vibration,
          speed: e.speed,
          gps_accuracy: e.gps_accuracy,
          recommended_action: e.event_type === 'severe_pothole' ? 'Perbaikan Darurat' : (e.event_type === 'pothole' ? 'Perbaikan Rutin' : 'Pemantauan')
        });
      }

      // Quality Logic
      const is_duration_sufficient = durationInSeconds >= 30;
      const is_reading_count_sufficient = count >= 30;
      const is_distance_sufficient = totalDistanceMeters >= 100;
      const is_speed_sufficient = avgSpeed >= 5;
      const is_gps_accuracy_acceptable = avgGpsAccuracy <= 25;

      let data_confidence_level = 'high';
      let report_validity_status = 'suitable_for_technical_review';
      const quality_notes: string[] = [];

      if (!is_duration_sufficient) quality_notes.push("Durasi terlalu singkat (<30s).");
      if (!is_reading_count_sufficient) quality_notes.push("Jumlah pembacaan terlalu sedikit (<30).");
      if (!is_distance_sufficient) quality_notes.push("Jarak tempuh terlalu pendek (<100m).");
      if (!is_speed_sufficient) quality_notes.push("Kecepatan rata-rata terlalu rendah (<5km/h).");
      if (!is_gps_accuracy_acceptable) quality_notes.push("Presisi GPS rata-rata buruk (>25m).");

      if (!is_duration_sufficient || !is_reading_count_sufficient || !is_distance_sufficient || !is_speed_sufficient) {
         data_confidence_level = 'low';
         report_validity_status = 'demo_only';
      } else if (!is_gps_accuracy_acceptable) {
         data_confidence_level = 'medium';
         report_validity_status = 'usable_for_preliminary_assessment';
      }

      let road_risk_level = calculateRiskLevel(eventsList, maxVibration, data_confidence_level);

      let conclusion = 'Membutuhkan data lebih lanjut.';
      if (road_risk_level === 'not_assessed') conclusion = 'Tidak ada validasi kerusakan jalan (tidak ada event valid).';
      else if (road_risk_level === 'low') conclusion = 'Jalan terpantau dalam kondisi baik.';
      else if (road_risk_level === 'medium') conclusion = 'Terdapat beberapa titik kerusakan ringan.';
      else if (road_risk_level === 'high') conclusion = 'Terdapat banyak lubang yang memerlukan perhatian.';
      else if (road_risk_level === 'critical') conclusion = 'Kerusakan jalan parah dan membahayakan.';

      // --- TECHNICAL SCORES LOGIC ---
      const distanceKm = totalDistanceMeters / 1000;
      const event_density_per_km = distanceKm > 0 ? (eventsList.length / distanceKm) : 0;
      const severe_event_ratio = eventsList.length > 0 ? (severePotholeCount / eventsList.length) : 0;
      const pothole_event_ratio = eventsList.length > 0 ? ((potholeCount + severePotholeCount) / eventsList.length) : 0;

      // data_quality_score: 0-100
      let dqScore = 0;
      if (is_duration_sufficient) dqScore += 20;
      if (is_reading_count_sufficient) dqScore += 20;
      if (is_distance_sufficient) dqScore += 20;
      if (is_speed_sufficient) dqScore += 20;
      if (is_gps_accuracy_acceptable) dqScore += 20;

      // gps_precision_score: 0-100
      let gpsScore = 0;
      if (avgGpsAccuracy <= 5.0) {
        gpsScore = 100;
      } else if (avgGpsAccuracy <= 10.0) {
        gpsScore = 80;
      } else if (avgGpsAccuracy <= 15.0) {
        gpsScore = 60;
      } else if (avgGpsAccuracy <= 25.0) {
        gpsScore = 40;
      } else if (avgGpsAccuracy <= 50.0) {
        gpsScore = 20;
      } else {
        gpsScore = 0;
      }

      // road_damage_score: 0-100
      let roadDamageScore: number | null = null;
      if (data_confidence_level !== 'low' || eventsList.length > 0) {
         let rawScore = (maxVibration * 5) + (event_density_per_km * 2) + (severe_event_ratio * 20);
         if (rawScore > 100) rawScore = 100;
         roadDamageScore = rawScore;
      }

      // --- GOVERNMENT WORKFLOW LOGIC ---
      let recommended_status = 'demo_data';
      let recommended_agency = 'Smart City Command Center';
      let follow_up_actions: string[] = [];

      if (data_confidence_level === 'low' && eventsList.length === 0) {
        recommended_status = 'demo_data';
        follow_up_actions = ["Survei ulang dengan durasi dan jarak yang memadai (>30 detik, >100m)."];
      } else if (data_confidence_level === 'medium' || (eventsList.length === 0 && !is_gps_accuracy_acceptable)) {
        recommended_status = 'needs_resurvey';
        follow_up_actions = ["Lakukan survei ulang dengan sinyal GPS yang lebih kuat (<25m)."];
      } else if (road_risk_level === 'medium') {
        recommended_status = 'needs_field_verification';
        follow_up_actions = ["Tugaskan tim untuk memverifikasi kerusakan ringan di lapangan."];
      } else if (road_risk_level === 'high') {
        recommended_status = 'forward_to_pupr';
        recommended_agency = 'Dinas PUPR';
        follow_up_actions = ["Teruskan laporan ke Dinas PUPR untuk perencanaan perbaikan rutin."];
      } else if (road_risk_level === 'critical') {
        recommended_status = 'urgent_review';
        recommended_agency = 'Dinas PUPR';
        follow_up_actions = ["Tinjauan darurat oleh Dinas PUPR.", "Pasang rambu peringatan pada titik kerusakan parah."];
      } else {
        recommended_status = 'demo_data';
        follow_up_actions = ["Pantau rutin jalan."];
      }

      // Segmentation logic (every 500m)
      const segments = [];
      let currentSegmentDistance = 0.0;
      let accumulatedTotalDistance = 0.0;
      let segReadingsCount = 0;
      let segMaxVibration = 0.0;
      let segSumVibration = 0.0;
      let segSumSpeed = 0.0;
      let segSumGps = 0.0;
      let segmentIndex = 1;
      let startRange = 0.0;
      let segStartTime = new Date(readings[0].recorded_at);
      let segEndTime = new Date(readings[0].recorded_at);

      const pushSegment = (endRange: number) => {
        if (segReadingsCount === 0) return;
        
        const segAvgVibration = segSumVibration / segReadingsCount;
        const segAvgSpeed = segSumSpeed / segReadingsCount;
        const segAvgGps = segSumGps / segReadingsCount;
        
        const segEvents = eventsList.filter((e) => {
          const eventTime = new Date(e.recorded_at).getTime();
          return eventTime >= segStartTime.getTime() && eventTime <= segEndTime.getTime();
        });

        let segConf = 'high';
        if (segReadingsCount < 10 || (endRange - startRange) < 50) segConf = 'low';
        else if (segAvgGps > 25) segConf = 'medium';

        let segRiskFinal = calculateRiskLevel(segEvents, segMaxVibration, segConf);

        segments.push({
          segment_index: segmentIndex,
          distance_start_m: Math.round(startRange),
          distance_end_m: Math.round(endRange),
          readings_count: segReadingsCount,
          event_count: segEvents.length,
          damaged_road_count: segEvents.filter(e => e.event_type === 'damaged_road').length,
          pothole_count: segEvents.filter(e => e.event_type === 'pothole').length,
          severe_pothole_count: segEvents.filter(e => e.event_type === 'severe_pothole').length,
          average_vibration: segAvgVibration.toFixed(2),
          max_vibration: segMaxVibration.toFixed(2),
          average_speed_kmh: segAvgSpeed.toFixed(2),
          average_gps_accuracy_m: segAvgGps.toFixed(2),
          road_risk_level: segRiskFinal,
          data_confidence_level: segConf,
          recommendation: segRiskFinal === 'critical' ? 'Perbaikan Segera' : (segRiskFinal === 'high' ? 'Perencanaan Perbaikan' : 'Pemantauan')
        });

        segmentIndex++;
        startRange = endRange;
        currentSegmentDistance = 0.0;
        segReadingsCount = 0;
        segMaxVibration = 0.0;
        segSumVibration = 0.0;
        segSumSpeed = 0.0;
        segSumGps = 0.0;
      };

      for (let i = 0; i < readings.length; i++) {
        const r = readings[i];
        segReadingsCount++;
        if (r.vibration > segMaxVibration) segMaxVibration = r.vibration;
        segSumVibration += r.vibration;
        segSumSpeed += r.speed;
        segSumGps += r.gps_accuracy;
        segEndTime = new Date(r.recorded_at);

        if (i > 0) {
          const prev = readings[i - 1];
          if (isValidCoordinate(prev.latitude, prev.longitude) && isValidCoordinate(r.latitude, r.longitude)) {
            const dist = haversineDistance(prev.latitude, prev.longitude, r.latitude, r.longitude);
            currentSegmentDistance += dist;
            accumulatedTotalDistance += dist;
          }
        }

        if (currentSegmentDistance >= 500.0) {
          pushSegment(accumulatedTotalDistance);
          segStartTime = new Date(r.recorded_at);
        }
      }

      if (segReadingsCount > 0) {
        pushSegment(accumulatedTotalDistance);
      }

      const photosList = photos || [];
      const photoEvidence = {
        total_photos: photosList.length,
        manual_photo_count: photosList.filter(p => p.photo_type === 'manual').length,
        event_photo_count: photosList.filter(p => p.photo_type === 'event').length,
        photos: photosList.map(p => ({
          id: p.id,
          taken_at: p.taken_at,
          caption: p.caption,
          photo_type: p.photo_type,
          latitude: p.latitude,
          longitude: p.longitude
        }))
      };

      input_summary = {
        input_summary_schema_version: "v4_photo_pdf_evidence",
        report_logic_version: "2026-07-03-confidence-risk-scoring",
        session_metadata: {
          session_id: session_id,
          title: sessionData.title,
          start_time: sessionData.start_time || readings[0].recorded_at,
          end_time: sessionData.end_time || readings[readings.length - 1].recorded_at,
          duration_seconds: durationInSeconds,
          generated_at: new Date().toISOString()
        },
        distance_speed_vibration_summary: {
          total_assessed_distance_m: segmentAnalyses ? segmentAnalyses.filter(s => s.road_condition !== 'not_assessed').reduce((sum, s) => sum + s.segment_length_m, 0) : 0,
          total_not_assessed_distance_m: segmentAnalyses ? segmentAnalyses.filter(s => s.road_condition === 'not_assessed').reduce((sum, s) => sum + s.segment_length_m, 0) : 0,
          dominant_condition: segmentAnalyses && segmentAnalyses.length > 0 ? segmentAnalyses.map(s => s.road_condition).sort((a,b) => segmentAnalyses.filter(v => v.road_condition===a).length - segmentAnalyses.filter(v => v.road_condition===b).length).pop() : 'not_assessed',
          segment_count: segmentAnalyses?.length || 0,
          segment_size_m: 100
        },
        trip_metrics: {
          total_readings: count,
          estimated_distance_m: Math.round(totalDistanceMeters),
          estimated_distance_km: (totalDistanceMeters / 1000).toFixed(2),
          average_speed_kmh: avgSpeed.toFixed(2),
          max_speed_kmh: maxSpeed.toFixed(2),
          average_vibration: avgVibration.toFixed(2),
          max_vibration: maxVibration.toFixed(2),
          average_gps_accuracy_m: avgGpsAccuracy.toFixed(2),
          min_gps_accuracy_m: minGpsAccuracy.toFixed(2),
          max_gps_accuracy_m: maxGpsAccuracy.toFixed(2)
        },
        data_quality: {
          data_confidence_level: data_confidence_level,
          report_validity_status: report_validity_status,
          is_duration_sufficient: is_duration_sufficient,
          is_reading_count_sufficient: is_reading_count_sufficient,
          is_speed_sufficient: is_speed_sufficient,
          is_distance_sufficient: is_distance_sufficient,
          is_gps_accuracy_acceptable: is_gps_accuracy_acceptable,
          quality_notes: quality_notes
        },
        event_summary: {
          total_events: eventsList.length,
          damaged_road_count: damagedRoadCount,
          pothole_count: potholeCount,
          severe_pothole_count: severePotholeCount,
          event_detection_rules: "speed >= 5 km/h, gps_accuracy <= 25 m, vibration >= thresholds (3.0, 5.0, 8.0)"
        },
        road_condition_assessment: {
          road_risk_level: road_risk_level,
          conclusion: conclusion,
          reason: "Berdasarkan gabungan frekuensi event kerusakan dan intensitas getaran maksimal."
        },
        technical_scores: {
          road_damage_score: roadDamageScore !== null ? Math.round(roadDamageScore) : null,
          road_damage_score_explanation: roadDamageScore === null ? "not assessed due to insufficient data" : "calculated from vibration and event density",
          data_quality_score: Math.round(dqScore),
          gps_precision_score: Math.round(gpsScore),
          event_density_per_km: Number(event_density_per_km.toFixed(2)),
          severe_event_ratio: Number(severe_event_ratio.toFixed(2)),
          pothole_event_ratio: Number(pothole_event_ratio.toFixed(2))
        },
        government_workflow: {
          recommended_status: recommended_status,
          recommended_agency: recommended_agency,
          follow_up_actions: follow_up_actions
        },
        segment_summary: segmentAnalyses || [],
        event_details: eventDetails,
        photo_evidence: photoEvidence
      };
    }

    if (input_summary.error) {
       return new Response(
        JSON.stringify({ error: input_summary.error }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!GOOGLE_AI_API_KEY) {
      return new Response(
        JSON.stringify({ error: "Server missing AI API Key configuration" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const systemInstruction = `Anda adalah analis ahli infrastruktur jalan. Buatlah Laporan Ilmiah Kondisi Jalan formal berbahasa Indonesia yang ditujukan untuk pelaporan Diskominfo / Smart City, serta koordinasi dengan Dinas PUPR.

ATURAN KETAT (WAJIB DIIKUTI):
1. Gunakan Bahasa Indonesia formal dan baku.
2. JANGAN MENGARANG DATA (No Hallucination). Gunakan HANYA data yang diberikan.
3. WAJIB GUNAKAN MARKDOWN TABLES (tabel) pada setiap bagian yang diinstruksikan.
4. Jika data quality (data_confidence_level) 'low' atau 'medium', NYATAKAN DENGAN JELAS bahwa laporan memiliki keterbatasan dan berstatus 'demo_only' atau 'limited'. JANGAN mengklaim jalan aman/rusak jika datanya tidak mendukung.
5. Gunakan istilah "presisi GPS" (semakin kecil nilai meternya, semakin baik).
6. Ingat: Tidak ada event bukan berarti jalan bagus, kecuali data confidence tinggi.
7. Tegaskan bahwa hasil ini adalah indikasi berbasis sensor smartphone dan memerlukan verifikasi lapangan (ground truth).
8. DILARANG KERAS menyimpulkan jalan rusak (high risk / critical) HANYA berdasarkan max_vibration tinggi jika tidak ada event kerusakan (total_events = 0) dan data_confidence_level = 'low'. Max vibration yang tinggi pada kecepatan sangat rendah (misal < 5km/h) adalah anomali sensor (guncangan tangan), BUKAN kerusakan jalan. Klasifikasikan sebagai 'not_assessed'.

STRUKTUR LAPORAN WAJIB (Gunakan ini sebagai heading):

# 1. Judul Laporan
Tulis judul laporan ilmiah.

# 2. Identitas Laporan
Gunakan tabel:
| Field | Nilai |

# 3. Ringkasan Eksekutif
Tulis narasi singkat, lalu gunakan tabel:
| Aspek | Hasil | Interpretasi |

# 4. Tujuan
Jelaskan tujuan laporan.

# 5. Metodologi dan Sumber Data
Gunakan tabel:
| Parameter | Sumber Data | Fungsi |

# 6. Standar Validasi Data
Gunakan tabel:
| Parameter | Nilai Aktual | Standar Minimal | Status |

# 7. Ringkasan Statistik Perjalanan
Gunakan tabel:
| Metrik | Nilai | Catatan |

# 8. Analisis Kualitas Data
Gunakan tabel:
| Indikator | Hasil | Status | Implikasi |

# 9. Analisis Getaran Jalan
Gunakan tabel:
| Metrik Getaran | Nilai | Interpretasi |

# 10. Analisis Event Kerusakan Jalan
Gunakan tabel:
| Jenis Event | Jumlah | Interpretasi |

# 11. Analisis Berbasis Jarak, Kecepatan, dan Guncangan
Gunakan tabel berikut untuk menampilkan kondisi per segmen:
| Segmen | Jarak | Kecepatan | Guncangan | Event | Kondisi Jalan | Skor | Solusi |

Jelaskan dalam narasi:
- Jika jarak suatu segmen kurang memadai, kondisi jalan tidak dapat dinilai.
- Jika kecepatan terlalu lambat, getaran tinggi dianggap sebagai anomali (bukan kerusakan jalan).
- Jika jarak dan kecepatan valid, serta guncangan/event tinggi, klasifikasikan sesuai tingkat kepercayaan.
- Rekomendasi solusi harus praktis untuk perbaikan pemeliharaan jalan (berdasarkan data).

# 12. Analisis Dampak dan Risiko
Gunakan tabel:
| Aspek Dampak | Tingkat Risiko | Alasan |

# 13. Rekomendasi Teknis
Gunakan tabel:
| Prioritas | Rekomendasi | Penanggung Jawab | Tujuan |

# 14. Rekomendasi untuk Diskominfo / Smart City
Gunakan tabel:
| Area | Rekomendasi |

# 15. Keterbatasan Data
Gunakan tabel:
| Keterbatasan | Dampak | Solusi |

# 16. Kesimpulan
Tulis kesimpulan laporan.

# 17. Lampiran Koordinat Event
Jika tidak ada event, tampilkan tabel:
| Status | Keterangan |
Jika ada event, tampilkan tabel (maksimal 10 baris jika terlalu banyak):
| Waktu | Latitude | Longitude | Event | Severity | Vibration | Speed | GPS Accuracy |

# 18. Lampiran Foto Dokumentasi Jalan
Foto ini adalah bukti visual pendukung kondisi lapangan.
Jika terdapat foto dalam data photo_evidence, gunakan tabel markdown berikut:
| Foto | Waktu | Koordinat | Tipe | Keterangan |
(Catatan: Kolom 'Foto' isi dengan teks "[Terlampir di dokumen PDF]" atau "[Foto ID]")
Jika tidak ada foto, tampilkan tabel:
| Status | Keterangan |
| Tidak ada foto | Tidak ada dokumentasi foto pada sesi ini |

# 19. Skor Teknis (Technical Score)
Gunakan tabel:
| Metrik | Skor / Nilai | Penjelasan |

# 20. Alur Kerja Pemerintah (Government Workflow)
Gunakan tabel:
| Status Rekomendasi | Instansi Tujuan |
(Jelaskan singkat mengenai status tersebut di bawah tabel)

# 21. Tindakan Lanjut (Follow-up Actions)
Gunakan tabel:
| Nomor | Tindakan Lanjut | Target Penyelesaian |`;

    const promptMessage = `Buatlah laporan berdasarkan input summary berikut ini (Trip: ${sessionData.title}):\n\n${JSON.stringify(input_summary, null, 2)}`;

    // Call Gemini API via fetch
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${GOOGLE_AI_MODEL}:generateContent?key=${GOOGLE_AI_API_KEY}`;
    
    const geminiRes = await fetch(geminiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        system_instruction: {
          parts: [{ text: systemInstruction }]
        },
        contents: [
          {
            role: "user",
            parts: [{ text: promptMessage }],
          },
        ],
        generationConfig: {
          temperature: 0.1, // Sangat rendah untuk pelaporan aktual
        },
      }),
    });

    if (!geminiRes.ok) {
      const errorText = await geminiRes.text();
      throw new Error(`Gemini API Error: ${geminiRes.status} ${errorText}`);
    }

    const geminiData = await geminiRes.json();
    const reportMarkdown = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!reportMarkdown) {
      throw new Error("Gemini returned empty response.");
    }

    // Save to database
    const { data: reportInsert, error: reportError } = await supabaseClient
      .from("ai_reports")
      .insert({
        user_id: user.id,
        session_id: session_id,
        title: `Laporan Analisis: ${sessionData.title}`,
        input_summary: input_summary,
        report_markdown: reportMarkdown,
        model_name: GOOGLE_AI_MODEL,
      })
      .select("id")
      .single();

    if (reportError || !reportInsert) {
      throw new Error(`Failed to save report: ${reportError?.message}`);
    }

    return new Response(
      JSON.stringify({ 
        report_id: reportInsert.id,
        report_markdown: reportMarkdown
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    console.error("Error generating report:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
