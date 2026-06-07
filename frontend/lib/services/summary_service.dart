import 'dart:convert';
import 'package:flutter/material.dart' show BuildContext, debugPrint;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:archive/archive.dart';
import 'dart:typed_data';
import '../supabase_service.dart';
import '../models.dart';

class SummaryService {
  
  static const double _saveRatio = 0.70;
  static const double _spendRatio = 0.20;
  static const double _shareRatio = 0.10;

  /// 🤖 CONNECTIVITY INTERFACE: Dispatches parameters straight to your Supabase Edge pipeline
  Future<String> _fetchAIInsight(WalletModel wallet, Map<String, dynamic>? goalData, double earned, double spent) async {
    try {
      final String goalName = goalData != null ? goalData['goal_name'] ?? 'None' : 'None';
      final double totalPool = wallet.totalBalance ?? 
          ((wallet.saveBalance ?? 0.0) + (wallet.spendBalance ?? 0.0) + (wallet.shareBalance ?? 0.0));

      final String? jwtToken = supabaseService.client.auth.currentSession?.accessToken;

      if (jwtToken == null) return _fallbackInsight;

      final Map<String, String> requestHeaders = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $jwtToken",
      };

      final response = await http.post(
        Uri.parse('https://tbrefzeytkflqyadayvs.supabase.co/functions/v1/analyze-ledger'),
        headers: requestHeaders,
        body: jsonEncode({
          "saveBalance": totalPool * _saveRatio,
          "spendBalance": totalPool * _spendRatio,
          "totalEarned": earned,
          "totalSpent": spent,
          "activeDream": goalName
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['insight'] != null) {
          return data['insight'] as String;
        }
      }
    } catch (e) {
      debugPrint('⚠️ summary_service: AI network handshake interrupted: $e');
    }
    return _fallbackInsight;
  }

  /// 🛠️ CORE COMPILER ENGINE: Generates a high-fidelity document object model instance in isolation.
  /// This can be cleanly consumed by both the single view printer and the batch archive processor!
/// 🛠️ CORE COMPILER ENGINE: Generates a high-fidelity document object model instance in isolation.
  /// Fully optimized to accept pre-fetched transactional structures from batch operations.
  Future<Uint8List> compileChildReportBytes(
    WalletModel wallet, 
    String childName, {
    List<dynamic>? preFetchedTransactions,
  }) async {
    final String? profileId = wallet.profileId;
    if (profileId == null) throw Exception("Profile ID scope unassigned.");

    final doc = pw.Document();
    final DateTime now = DateTime.now();
    final String currentMonthStr = DateFormat('MMMM yyyy').format(now);

    Map<String, dynamic>? goalData;
    List<dynamic> txData = [];
    String aiInsight = _fallbackInsight;

    try {
      // 1. CONDITIONAL HYDRATION LANE: Differentiates Single vs Batch modes
      if (preFetchedTransactions != null) {
        // 🚀 BATCH MODE: Reuse pre-fetched transactions directly; fetch missing goal row
        txData = preFetchedTransactions;
        try {
          goalData = await supabaseService.client
              .from('savings_goals')
              .select('goal_name, target_amount, status')
              .eq('profile_id', profileId)
              .maybeSingle();
        } catch (e) {
          debugPrint('⚠️ summary_service: Error resolving child goal metric context: $e');
        }
      } else {
        // 📑 SINGLE MODE: Aggregate full data tables concurrently over a 10s network threshold
        final dynamic aggregatedData = await Future.wait<dynamic>([
          supabaseService.client.from('savings_goals').select('goal_name, target_amount, status').eq('profile_id', profileId).maybeSingle(),
          supabaseService.client.from('transactions').select('title, category, amount').eq('profile_id', profileId).order('created_at', ascending: false),
        ]).timeout(
          const Duration(seconds: 10),
          onTimeout: () => [null, <dynamic>[]],
        );

        goalData = aggregatedData[0];
        txData = aggregatedData[1] as List<dynamic>;
      }

      // Calculate total dynamic earned and spent aggregates
      double totalEarned = 0.0;
      double totalSpent = 0.0;
      for (var tx in txData) {
        final double amt = (tx['amount'] ?? 0.0).toDouble();
        amt >= 0 ? totalEarned += amt : totalSpent += amt.abs();
      }

      // Fetch DuitWise AI Mentor Insights or fall back cleanly
      try {
        aiInsight = await _fetchAIInsight(wallet, goalData, totalEarned, totalSpent);
      } catch (e) {
        debugPrint('⚠️ Failed to resolve Edge insight engine parameters: $e');
      }

      final double totalCoins = wallet.totalBalance ?? 
          ((wallet.saveBalance ?? 0.0) + (wallet.spendBalance ?? 0.0) + (wallet.shareBalance ?? 0.0));

      // 2. DOCUMENT CANVAS CONSTRUCTION VIEWPORT
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
            ),
          ),
          build: (pw.Context context) {
            return [
              // --- SECTION A: HEADER IDENTITY ---
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

              // --- SECTION B: DUKITWISE AI INSIGHT CARD ---
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
                    pw.Paragraph(
                      text: aiInsight,
                      style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#4C1D95'), height: 1.4),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // --- SECTION C: BALANCE SHEET BOXES ---
              pw.Text('Pocket Allocations Balance Sheet', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildCleanStatBox('SAVE WALLET (70%)', 'RM ${(totalCoins * _saveRatio).toStringAsFixed(2)}', '#16A34A', '#DCFCE7'),
                  _buildCleanStatBox('SPEND CASH (20%)', 'RM ${(totalCoins * _spendRatio).toStringAsFixed(2)}', '#2563EB', '#DBEAFE'),
                  _buildCleanStatBox('SHARE POCKET (10%)', 'RM ${(totalCoins * _shareRatio).toStringAsFixed(2)}', '#DB2777', '#FCE7F3'),
                ],
              ),
              pw.SizedBox(height: 24),

              // --- SECTION D: TARGET GOALS CARDS ---
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
                child: _buildSavingsGoalWidget(goalData),
              ),
              pw.SizedBox(height: 24),

              // --- SECTION E: TRANSACTION HISTORY SUMMARY TABLE ---
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

              _buildTransactionTable(txData),
            ];
          },
        ),
      );

    } catch (e) {
      debugPrint('Document generation pipeline runtime fatal crash: $e');
    }

    return doc.save();
  }

  /// 📑 SINGLE CHANNEL: Compiles layout and pops open native presentation preview window natively
  Future<void> generateAndDownloadReport(BuildContext context, WalletModel wallet, String childName) async {
    try {
      final Uint8List pdfBytes = await compileChildReportBytes(wallet, childName);
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'DuitWise_AI_Summary_${childName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      debugPrint('Document generation layout terminal error: $e');
    }
  }

  /// ⚡ PREMIUM CONCURRENT BATCH ENGINE: Resolves full-fidelity styled reports concurrently into a ZIP container.
/// ⚡ PREMIUM CONCURRENT BATCH ENGINE: Resolves full-fidelity styled reports concurrently into a ZIP container.
/// ⚡ PREMIUM CONCURRENT BATCH ENGINE: Resolves full-fidelity styled reports concurrently into a ZIP container.
  Future<void> generateAndShareHouseholdZipArchive(List<dynamic> kidsList) async {
    final Archive familyArchive = Archive();

    final List<Future<void>> compilationTasks = kidsList.map((kid) async {
      final String kidName = kid['username'] ?? 'Young Saver';
      final String kidId = kid['id']?.toString() ?? '';
      final dynamic walletMap = kid['wallets'];
      
      // 🔬 DIAGNOSTIC LIFELINE: Let's inspect exactly what Supabase returns for transactions
      debugPrint('📦 DuitWise Batch Processing: $kidName (ID: $kidId)');
      debugPrint('📦 Raw Linked Transaction Data Type: ${kid['transactions'].runtimeType}');
      debugPrint('📦 Raw Linked Transaction Payload: ${kid['transactions']}');

      // 🎯 EXTRA-BULLETPROOF EXTRACTION: Handle variations in PostgREST JSON structures
      List<dynamic> preFetchedTx = [];
      if (kid['transactions'] != null) {
        if (kid['transactions'] is List) {
          preFetchedTx = kid['transactions'] as List<dynamic>;
        } else if (kid['transactions'] is Map) {
          // Fallback case if returned as a nested map container object
          final dynamic embeddedList = kid['transactions']['data'] ?? kid['transactions']['records'];
          if (embeddedList is List) {
            preFetchedTx = embeddedList as List<dynamic>;
          }
        }
      }
      
      double total = 0.00;
      double save = 0.00;
      double spend = 0.00;
      double share = 0.00;

      // Handle both List and Map variants for the nested wallet entity relation
      dynamic targetWalletMap;
      if (walletMap != null) {
        if (walletMap is List && walletMap.isNotEmpty) {
          targetWalletMap = walletMap.first;
        } else if (walletMap is Map) {
          targetWalletMap = walletMap;
        }
      }

      if (targetWalletMap != null && targetWalletMap is Map) {
        save = double.parse((targetWalletMap['save_balance'] ?? 0.0).toString());
        spend = double.parse((targetWalletMap['spend_balance'] ?? 0.0).toString());
        share = double.parse((targetWalletMap['share_balance'] ?? 0.0).toString());
        total = targetWalletMap['total_balance'] != null 
            ? double.parse(targetWalletMap['total_balance'].toString())
            : (save + spend + share);
      }

      final childWalletContext = WalletModel(
        profileId: kidId,
        totalBalance: total,
        saveBalance: save,
        spendBalance: spend,
        shareBalance: share,
      );

      final Uint8List highFidelityPdfBytes = await compileChildReportBytes(
        childWalletContext, 
        kidName,
        preFetchedTransactions: preFetchedTx, 
      );
      
      final String safeFileName = "${kidName.replaceAll(RegExp(r'[^\w\s]+'), '')}_Monthly_Statement.pdf";

      familyArchive.addFile(
        ArchiveFile(safeFileName, highFidelityPdfBytes.length, highFidelityPdfBytes),
      );
    }).toList();

    await Future.wait(compilationTasks);

    if (familyArchive.isEmpty) throw Exception("Failed to group document buffers.");

    final archiveEncoder = ZipEncoder();
    final List<int>? rawEncodedBytes = archiveEncoder.encode(familyArchive);
    
    if (rawEncodedBytes == null) throw Exception("ZIP streaming encoder dropped.");
    
    final Uint8List outputZipBuffer = Uint8List.fromList(rawEncodedBytes);

    await Printing.sharePdf(
      bytes: outputZipBuffer,
      filename: "Household_Monthly_Reports_${DateTime.now().millisecondsSinceEpoch}.zip",
    );
  }

  // --- PRIVATE LAYOUT COMPOSTING METHODS ---

  static pw.Widget _buildCleanStatBox(String label, String value, String hexText, String hexBg) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      width: 160,
      decoration: pw.BoxDecoration(color: PdfColor.fromHex(hexBg), borderRadius: pw.BorderRadius.circular(12)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex(hexText), letterSpacing: 0.5)),
          pw.SizedBox(height: 6),
          pw.Text(value, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex(hexText))),
        ],
      ),
    );
  }

  static pw.Widget _buildSavingsGoalWidget(Map<String, dynamic>? goalData) {
    if (goalData == null) {
      return pw.Text('No active savings target locked for this cycle period yet.', style: pw.TextStyle(fontSize: 10.5, fontStyle: pw.FontStyle.italic, color: PdfColor.fromHex('#64748B')));
    }

    final String statusText = (goalData['status'] ?? 'active').toString().toLowerCase().trim();
    final bool isCompleted = statusText == 'achieved' || statusText == 'completed';
    final double targetPrice = (goalData['target_amount'] ?? 0.0).toDouble();
    final String goalName = goalData['goal_name'] ?? 'Saving Dream';

    if (isCompleted) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text('🎉 Mission Accomplished: ', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#16A34A'))),
                  pw.Text(goalName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E2937'))),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text('Outstanding achievement! Target fully unlocked and rewarded!', style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#16A34A'), fontStyle: pw.FontStyle.italic)),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#DCFCE7'), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Text('RM ${targetPrice.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#16A34A'))),
          ),
        ],
      );
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Active Goal: $goalName', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E2937'))),
            pw.SizedBox(height: 2),
            pw.Text('Keep executing milestones to unlock this reward!', style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#64748B'))),
          ],
        ),
        pw.Text('RM ${targetPrice.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
      ],
    );
  }

  static pw.Widget _buildTransactionTable(List<dynamic> txData) {
    if (txData.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 24),
        child: pw.Center(child: pw.Text('No transactional operations logged for this history ledger yet.', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColor.fromHex('#64748B')))),
      );
    }

    return pw.Table(
      border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColor.fromHex('#F1F5F9'), width: 1), bottom: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 1.5)),
      columnWidths: const {0: pw.FlexColumnWidth(3.0), 1: pw.FlexColumnWidth(1.2), 2: pw.FlexColumnWidth(1.2)},
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
          children: [_buildHeaderCell('Transaction Description Log'), _buildHeaderCell('Category'), _buildHeaderCell('Net Value Impact')],
        ),
        ...txData.map((tx) {
          final double amt = (tx['amount'] ?? 0.0).toDouble();
          final String prefix = amt >= 0 ? '+' : '-';
          return pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Paragraph(text: tx['title'] ?? 'Coin Movement Record', style: const pw.TextStyle(fontSize: 9.5), margin: pw.EdgeInsets.zero)),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text(tx['category'] ?? 'General', style: const pw.TextStyle(fontSize: 9.5))),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: pw.Text('$prefix RM ${amt.abs().toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: amt >= 0 ? PdfColor.fromHex('#16A34A') : PdfColor.fromHex('#DC2626'))),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8), child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E2937'), fontSize: 9.5)));
  }

  static const String _fallbackInsight = 
      'Fantastic work tracking your ledger this month! Your savings rate is steady. Keep checking your missions list to build continuous habits towards your big goals!';
}