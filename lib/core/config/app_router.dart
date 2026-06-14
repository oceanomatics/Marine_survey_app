// lib/core/config/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/cases/screens/cases_list_screen.dart';
import '../../features/cases/screens/case_home_screen.dart';
import '../../features/cases/screens/new_case_screen.dart';
import '../../features/vessel/screens/vessel_particulars_screen.dart';
import '../../features/survey/screens/damage_register_screen.dart';
import '../../features/capture/screens/camera_screen.dart';
import '../../features/capture/screens/voice_note_screen.dart';
import '../../features/capture/screens/quick_capture_screen.dart';
import '../../features/documents/screens/document_vault_screen.dart';
import '../../features/checklist/screens/checklist_screen.dart';
import '../../features/reports/screens/report_builder_screen.dart';
import '../../features/correspondence/screens/inbox_screen.dart';
import '../../features/timesheet/screens/timesheet_screen.dart';
import '../../shared/screens/login_screen.dart';
import '../../core/api/supabase_client.dart';

final appRouter = GoRouter(
  initialLocation: '/cases',
  redirect: (context, state) {
    final isLoggedIn = SupabaseService.currentUser != null;
    final isLoginPage = state.matchedLocation == '/login';
    if (!isLoggedIn && !isLoginPage) return '/login';
    if (isLoggedIn && isLoginPage) return '/cases';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    // ── Cases ──────────────────────────────────────────────────────────────
    GoRoute(
      path: '/cases',
      builder: (context, state) => const CasesListScreen(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => const NewCaseScreen(),
        ),
        GoRoute(
          path: ':caseId',
          builder: (context, state) {
            final caseId = state.pathParameters['caseId']!;
            return CaseHomeScreen(caseId: caseId);
          },
          routes: [
            // Vessel particulars
            GoRoute(
              path: 'vessel',
              builder: (context, state) {
                final caseId = state.pathParameters['caseId']!;
                return VesselParticularsScreen(caseId: caseId);
              },
            ),
            // Damage register
            GoRoute(
              path: 'damage',
              builder: (context, state) {
                final caseId = state.pathParameters['caseId']!;
                return DamageRegisterScreen(caseId: caseId);
              },
            ),
            // Camera
            GoRoute(
              path: 'camera',
              builder: (context, state) {
                final caseId = state.pathParameters['caseId']!;
                final section = state.uri.queryParameters['section'];
                return CameraScreen(caseId: caseId, reportSection: section);
              },
            ),
            // Voice notes
            GoRoute(
              path: 'voice',
              builder: (context, state) {
                final caseId = state.pathParameters['caseId']!;
                return VoiceNoteScreen(caseId: caseId);
              },
            ),
            // Quick capture inbox
            GoRoute(
              path: 'capture',
              builder: (context, state) {
                final caseId = state.pathParameters['caseId']!;
                return QuickCaptureScreen(caseId: caseId);
              },
            ),
            // Document vault
            GoRoute(
              path: 'documents',
              builder: (context, state) {
                final caseId = state.pathParameters['caseId']!;
                return DocumentVaultScreen(caseId: caseId);
              },
            ),
            // Checklist
            GoRoute(
              path: 'checklist',
              builder: (context, state) {
                final caseId = state.pathParameters['caseId']!;
                final stage = state.uri.queryParameters['stage'];
                return ChecklistScreen(caseId: caseId, stage: stage);
              },
            ),
            // Report builder
            GoRoute(
              path: 'reports',
              builder: (context, state) {
                final caseId = state.pathParameters['caseId']!;
                return ReportBuilderScreen(caseId: caseId);
              },
            ),
          ],
        ),
      ],
    ),

    // ── Correspondence (global inbox) ──────────────────────────────────────
    GoRoute(
      path: '/inbox',
      builder: (context, state) => const InboxScreen(),
    ),

    // ── Timesheet ──────────────────────────────────────────────────────────
    GoRoute(
      path: '/timesheet',
      builder: (context, state) => const TimesheetScreen(),
    ),
  ],
);
