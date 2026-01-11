import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_constants.dart';
import '../../../services/api_service.dart';

part 'language_event.dart';
part 'language_state.dart';

class LanguageBloc extends Bloc<LanguageEvent, LanguageState> {
  LanguageBloc() : super(const LanguageState(locale: Locale('en'))) {
    on<LoadLanguage>(_onLoadLanguage);
    on<ChangeLanguage>(_onChangeLanguage);
  }
  
  Future<void> _onLoadLanguage(LoadLanguage event, Emitter<LanguageState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(AppConstants.languageKey) ?? 'en';
    emit(LanguageState(locale: Locale(languageCode)));
  }
  
  Future<void> _onChangeLanguage(ChangeLanguage event, Emitter<LanguageState> emit) async {
    emit(LanguageState(locale: event.locale));
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.languageKey, event.locale.languageCode);
    
    // تحديث اللغة في الخادم إذا كان المستخدم مسجل دخول
    final isLoggedIn = prefs.getBool(AppConstants.isLoggedInKey) ?? false;
    if (isLoggedIn) {
      try {
        await ApiService().updateLanguage(event.locale.languageCode);
      } catch (e) {
        // لا نعرض خطأ للمستخدم لأن هذا ليس حرجاً
        debugPrint('Warning: Failed to update language on server: $e');
      }
    }
  }
}


