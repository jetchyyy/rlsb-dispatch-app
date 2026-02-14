import 'package:flutter/material.dart';
import '../../domain/entities/dispatch.dart';
import '../../domain/usecases/get_dispatch_list.dart';

enum DispatchState { initial, loading, loaded, error }

class DispatchProvider extends ChangeNotifier {
  final GetDispatchList getDispatchList;

  DispatchProvider({required this.getDispatchList});

  DispatchState _state = DispatchState.initial;
  List<Dispatch> _dispatches = [];
  Dispatch? _selectedDispatch;
  String? _errorMessage;

  DispatchState get state => _state;
  List<Dispatch> get dispatches => _dispatches;
  Dispatch? get selectedDispatch => _selectedDispatch;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == DispatchState.loading;
  bool get hasData => _dispatches.isNotEmpty;

  Future<void> fetchDispatches() async {
    _state = DispatchState.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await getDispatchList();

    result.fold(
      (failure) {
        _state = DispatchState.error;
        _errorMessage = failure.message;
        _dispatches = [];
        notifyListeners();
      },
      (dispatches) {
        _state = DispatchState.loaded;
        _dispatches = dispatches;
        _errorMessage = null;
        notifyListeners();
      },
    );
  }

  void selectDispatch(Dispatch dispatch) {
    _selectedDispatch = dispatch;
    notifyListeners();
  }

  void clearSelectedDispatch() {
    _selectedDispatch = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}