import 'dart:convert';
import 'package:flutter/material.dart' show BuildContext, debugPrint;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../supabase_service.dart';
import '../models.dart';

class SummaryService {
  // 🧠 Connects to the Python backend method to fetch custom OpenRouter insights
Future<String> _fetchAIInsight(WalletModel wallet, Map<String, dynamic>? goalData, double earned, double spent) async {
  try {
    final String goalName = goalData != null ? goalData['goal_name'] ?? 'None' : 'None';
    
    final double totalPool = wallet.totalBalance ?? 
        ((wallet.saveBalance ?? 0.0) + (wallet.spendBalance ?? 0.0) + (wallet.shareBalance ?? 0.0));

    // 🔑 THE CORRECT WAY: Extract the live User JWT Access Token from the active session
    final String? jwtToken = supabaseService.client.auth.currentSession?.accessToken;

    if (jwtToken == null) {
      debugPrint('⚠️ summary_service: No active authenticated session found. Aborting AI fetch.');
      return 'Fantastic work tracking your ledger this month! Your savings rate is steady.';
    }

    final Map<String, String> requestHeaders = {
      "Content-Type": "application/json",
      // Pass the user's specific bearer token. The Edge function decodes this to know exactly which child is requesting the data!
      "Authorization": "Bearer $jwtToken",
    };

    debugPrint('📡 summary_service: Dispatching payload vectors to Edge function...');

    final response = await http.post(
      Uri.parse('https://tbrefzeytkflqyadayvs.supabase.co/functions/v1/analyze-ledger'),
      headers: requestHeaders,
      body: jsonEncode({
        "saveBalance": totalPool * 0.70,
        "spendBalance": totalPool * 0.20,
        "totalEarned": earned,
        "totalSpent": spent,
        "activeDream": goalName
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data != null && data['insight'] != null) {
        return data['insight'] as String;
      }
    } else {
      debugPrint('⚠️ summary_service: Edge function rejected invocation. Status: ${response.statusCode}, Body: ${response.body}');
    }
  } catch (e) {
    debugPrint('⚠️ summary_service: Network stream breakdown: $e');
  }
  
  return 'Fantastic work tracking your ledger this month! Your savings rate is steady. Keep checking your missions list to build continuous habits towards your big goals!';
}

  // 🛠️ COHERENT INTERFACE: Takes childName dynamically to format statements beautifully for both scopes
  Future<void> generateAndDownloadReport(BuildContext context, WalletModel wallet, String childName) async {
    final String? profileId = wallet.profileId;
    if (profileId == null) return;

    final doc = pw.Document();
    final DateTime now = DateTime.now();
    final String currentMonthStr = DateFormat('MMMM yyyy').format(now);

    Map<String, dynamic>? goalData;
    List<dynamic> txData = [];
    String aiInsight = 'Fantastic work tracking your ledger this month! Your savings rate is steady. Keep checking your missions list to build continuous habits towards your big goals!';

    try {
      // 1. Concurrent Fetch with 10s Timeout Limit
      final dynamic aggregatedData = await Future.wait<dynamic>([
        supabaseService.client.from('savings_goals').select('*').eq('profile_id', profileId).maybeSingle(),
        supabaseService.client.from('transactions').select('*').eq('profile_id', profileId).order('created_at', ascending: false),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () => [null, <dynamic>[]],
      );

      goalData = aggregatedData[0];
      txData = aggregatedData[1] as List<dynamic>;

      double totalEarned = 0.0;
      double totalSpent = 0.0;
      for (var tx in txData) {
        final double amt = (tx['amount'] ?? 0.0).toDouble();
        if (amt >= 0) {
          totalEarned += amt;
        } else {
          totalSpent += amt.abs();
        }
      }

      // 🤖 Fetch AI insights or gracefully use system fallback strings
      try {
        aiInsight = await _fetchAIInsight(wallet, goalData, totalEarned, totalSpent)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('⚠️ AI endpoint unreached. Applying local engine copy fallback context rules: $e');
      }

      final double totalCoins = wallet.totalBalance ?? 
          ((wallet.saveBalance ?? 0.0) + (wallet.spendBalance ?? 0.0) + (wallet.shareBalance ?? 0.0));

      // 2. Document Canvas Build Pattern
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('DUITWISE FINANCIAL LOG', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#8B5CF6'), letterSpacing: 1.2)),
                        pw.SizedBox(height: 4),
                        pw.Text('$childName\'s Monthly Statement', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                        pw.SizedBox(height: 2),
                        pw.Text('Period: $currentMonthStr', style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#64748B'))),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9'), borderRadius: pw.BorderRadius.circular(12)),
                      child: pw.Text('Smart Saver Account', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#334155'))),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1),
                pw.SizedBox(height: 16),

                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F5F3FF'),
                    borderRadius: pw.BorderRadius.circular(16), 
                    border: pw.Border.all(color: PdfColor.fromHex('#DDD6FE'), width: 1.2), 
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DuitWise AI Mentor Insights', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#6D28D9'))),
                      pw.SizedBox(height: 6),
                      pw.Container(height: 2, width: 40, decoration: pw.BoxDecoration(color: PdfColor.fromHex('#8B5CF6'))),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        aiInsight,
                        style: pw.TextStyle(fontSize: 10.5, color: PdfColor.fromHex('#4C1D95'), height: 1.4),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                pw.Text('Pocket Allocations Balance Sheet', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCleanStatBox('SAVE WALLET (70%)', 'RM ${(totalCoins * 0.70).toStringAsFixed(2)}', '#16A34A', '#DCFCE7'),
                    _buildCleanStatBox('SPEND CASH (20%)', 'RM ${(totalCoins * 0.20).toStringAsFixed(2)}', '#2563EB', '#DBEAFE'),
                    _buildCleanStatBox('SHARE POCKET (10%)', 'RM ${(totalCoins * 0.10).toStringAsFixed(2)}', '#DB2777', '#FCE7F3'),
                  ],
                ),
                pw.SizedBox(height: 24),

                pw.Text('Target Goals & Long-Term Dreams', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                pw.SizedBox(height: 10),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                    borderRadius: pw.BorderRadius.circular(14),
                    border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1.5),
                  ),
                  child: goalData != null
                      ? pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Active Goal: ${goalData['goal_name']}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E2937'))),
                                pw.SizedBox(height: 2),
                                pw.Text('Keep executing milestones to unlock this reward!', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B'))),
                              ],
                            ),
                            pw.Text('RM ${(goalData['target_amount'] ?? 0.0).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                          ],
                        )
                      : pw.Text('No active savings target locked for this cycle period yet.', style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic, color: PdfColor.fromHex('#64748B'))),
                ),
                pw.SizedBox(height: 24),

                pw.Text('Account Activity Summary Ledger', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Comprehensive transaction operations feed log.', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B'))),
                    pw.Text('Earned: +RM ${totalEarned.toStringAsFixed(2)}  |  Spent: -RM ${totalSpent.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#334155'))),
                  ],
                ),
                pw.SizedBox(height: 10),

                if (txData.isNotEmpty)
                  pw.TableHelper.fromTextArray(
                    border: pw.TableBorder(
                      horizontalInside: pw.BorderSide(color: PdfColor.fromHex('#F1F5F9'), width: 1),
                      bottom: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 1.5),
                    ),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E2937'), fontSize: 10),
                    headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellHeight: 26,
                    cellStyle: const pw.TextStyle(fontSize: 10),
                    headers: ['Transaction Description Log', 'Category', 'Net Value Impact'],
                    data: txData.take(8).map((tx) {
                      final double amt = (tx['amount'] ?? 0.0).toDouble();
                      final String prefix = amt >= 0 ? '+' : '-';
                      return [
                        tx['title'] ?? 'Coin Movement Record',
                        tx['category'] ?? 'General',
                        '$prefix RM ${amt.abs().toStringAsFixed(2)}',
                      ];
                    }).toList(),
                  )
                else
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 20),
                    child: pw.Center(
                      child: pw.Text('No transactional operations logged for this cycle history ledger yet.', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColor.fromHex('#64748B'))),
                    ),
                  ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'DuitWise_AI_Summary_${childName}_${now.millisecondsSinceEpoch}.pdf',
      );

    } catch (e) {
      debugPrint('Document generation pipeline runtime fatal crash: $e');
    }
  }

  static pw.Widget _buildCleanStatBox(String label, String value, String hexText, String hexBg) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      width: 148,
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex(hexBg),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex(hexText), letterSpacing: 0.5)),
          pw.SizedBox(height: 6),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex(hexText))),
        ],
      ),
    );
  }
}