// lib/core/config/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/cases/screens/cases_list_screen.dart';
import '../../features/cases/screens/case_home_screen.dart';
import '../../features/cases/screens/new_case_screen.dart';
import '../../features/vessel/screens/vessel_particulars_screen.dart';
import '../../features/survey/screens/damage_register_screen.dart';
import '../../features/survey/screens/occurrence_screen.dart';
import '../../features/survey/screens/causation_screen.dart';
import '../../features/survey/screens/repair_periods_screen.dart';
import '../../features/capture/screens/camera_screen.dart';
import '../../features/capture/screens/voice_note_screen.dart';
import '../../features/capture/screens/quick_capture_screen.dart';
import '../../features/documents/screens/document_vault_screen.dart';
import '../../features/checklist/screens/checklist_screen.dart';
import '../../features/reports/screens/report_builder_screen.dart';
import '../../features/survey/screens/attendees_screen.dart';
import '../../features/parties/screens/parties_screen.dart';
import '../../features/attendances/screens/attendances_screen.dart';
import '../../features/timeline/screens/timeline_screen.dart';
import '../../features/photos/screens/photo_gallery_screen.dart';
import '../../features/correspondence/screens/inbox_screen.dart';
import '../../features/correspondence/screens/correspondence_screen.dart';
import '../../features/background/screens/background_screen.dart';
import '../../features/surveyor_notes/screens/surveyor_notes_screen.dart';
import '../../features/hse/screens/hse_screen.dart';
import '../../features/analyst/screens/case_analyst_screen.dart';
import '../../features/timesheet/screens/timesheet_screen.dart';
import '../../features/settings/screens/usage_screen.dart';
import '../../features/settings/screens/account_screen.dart';
import '../../features/settings/screens/debug_log_screen.dart';
import '../../features/settings/screens/speech_settings_screen.dart';
import '../../features/settings/screens/organisation_list_screen.dart';
import '../../features/settings/screens/organisation_detail_screen.dart';
import '../../features/interviews/screens/interview_screen.dart';
import '../../features/interviews/screens/interview_list_screen.dart';
import '../../features/interviews/screens/record_interview_screen.dart';
import '../../features/accounts/screens/accounts_screen.dart';
import '../../features/accounts/screens/invoice_detail_screen.dart';
import '../../shared/screens/login_screen.dart';
import '../../core/api/supabase_client.dart';

final appRouter = GoRouter(
  initialLocation: '/cases',
  redirect: (BuildContext context, GoRouterState state) {
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
          builder: (context, state) =>
              CaseHomeScreen(caseId: state.pathParameters['caseId']!),
          routes: [
            GoRoute(
              path: 'vessel',
              builder: (context, state) =>
                  VesselParticularsScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'damage',
              builder: (context, state) =>
                  DamageRegisterScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'repairs',
              builder: (context, state) =>
                  RepairPeriodsScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'camera',
              builder: (context, state) => CameraScreen(
                caseId: state.pathParameters['caseId']!,
                reportSection: state.uri.queryParameters['section'],
              ),
            ),
            GoRoute(
              path: 'voice',
              builder: (context, state) =>
                  VoiceNoteScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'capture',
              builder: (context, state) =>
                  QuickCaptureScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'documents',
              builder: (context, state) =>
                  DocumentVaultScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'checklist',
              builder: (context, state) => ChecklistScreen(
                caseId: state.pathParameters['caseId']!,
                stage: state.uri.queryParameters['stage'],
              ),
            ),
            GoRoute(
              path: 'occurrence',
              builder: (context, state) =>
                  OccurrenceScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'causation',
              builder: (context, state) =>
                  CausationScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'attendees',
              builder: (context, state) =>
                  AttendeesScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'parties',
              builder: (context, state) =>
                  PartiesScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'attendances',
              builder: (context, state) =>
                  AttendancesScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'timeline',
              builder: (context, state) =>
                  TimelineScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'photos',
              builder: (context, state) =>
                  PhotoGalleryScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'correspondence',
              builder: (context, state) =>
                  CorrespondenceScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'background',
              builder: (context, state) =>
                  BackgroundScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'notes',
              builder: (context, state) =>
                  SurveyorNotesScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'hse',
              builder: (context, state) =>
                  HseScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'analyst',
              builder: (context, state) =>
                  CaseAnalystScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'interview',
              builder: (context, state) =>
                  InterviewScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'interviews',
              builder: (context, state) =>
                  InterviewListScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'interviews/record',
              builder: (context, state) =>
                  RecordInterviewScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'reports',
              builder: (context, state) =>
                  ReportBuilderScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'accounts',
              builder: (context, state) =>
                  AccountsScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: 'accounts/:documentId',
              builder: (context, state) => InvoiceDetailScreen(
                caseId: state.pathParameters['caseId']!,
                documentId: state.pathParameters['documentId']!,
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/inbox',
      builder: (context, state) => const InboxScreen(),
    ),
    GoRoute(
      path: '/timesheet',
      builder: (context, state) => const TimesheetScreen(),
    ),
    GoRoute(
      path: '/usage',
      builder: (context, state) => const UsageScreen(),
    ),
    GoRoute(
      path: '/account',
      builder: (context, state) => const AccountScreen(),
    ),
    GoRoute(
      path: '/debug-log',
      builder: (context, state) => const DebugLogScreen(),
    ),
    GoRoute(
      path: '/speech-settings',
      builder: (context, state) => const SpeechSettingsScreen(),
    ),
    GoRoute(
      path: '/organisations',
      builder: (context, state) => const OrganisationListScreen(),
    ),
    GoRoute(
      path: '/organisations/:orgId',
      builder: (context, state) => OrganisationDetailScreen(
        orgId: state.pathParameters['orgId']!,
      ),
    ),
  ],
);
