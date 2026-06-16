// PATCH: add to app_router.dart inside the :caseId routes block
// Add this GoRoute alongside vessel, damage, camera etc:

// import '../../features/survey/screens/attendees_screen.dart';
// ... then inside the :caseId routes list:

/*
GoRoute(
  path: 'attendees',
  builder: (context, state) =>
      AttendeesScreen(caseId: state.pathParameters['caseId']!),
),
*/

// Also add to case_home_screen.dart _moduleButtons list:
/*
_ModuleButton(
  icon: Icons.people_outline,
  label: 'Attendees',
  color: AppColors.navy,
  bgColor: AppColors.lightBlue,
  onTap: () => context.go('/cases/$caseId/attendees'),
),
*/
