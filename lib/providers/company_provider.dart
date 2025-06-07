import 'package:flutter/material.dart';
import '../models/company.dart';
import '../services/api_service.dart';

class CompanyProvider with ChangeNotifier {
  List<Company> _companies = [];
  bool _isLoading = false;
  String _errorMessage = '';

  List<Company> get companies => _companies;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  Future<void> loadCompanies() async {
    try {
      setLoading(true);
      clearError();

      print("회사 목록을 로딩 중...");

      final response = await ApiService().getCompanies();
      print(response);

      if (response['companies'] != null) {
        final companiesList = response['companies'] as List;
        _companies = companiesList
            .map((company) => Company.fromJson(company))
            .toList();
      } else {
        _companies = [];
      }

      notifyListeners();
    } catch (e) {
      setError('회사 목록 로딩에 실패했습니다: ${e.toString()}');
      _companies = [];
      notifyListeners();
    } finally {
      setLoading(false);
    }
  }

  Company? getCompanyById(String id) {
    try {
      return _companies.firstWhere((company) => company.id == id);
    } catch (e) {
      return null;
    }
  }
}
