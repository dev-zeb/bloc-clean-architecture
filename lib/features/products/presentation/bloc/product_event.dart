import 'package:equatable/equatable.dart';

abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => [];
}

class ProductStarted extends ProductEvent {
  const ProductStarted();
}

class ProductNextPageRequested extends ProductEvent {
  const ProductNextPageRequested();
}

class ProductRefreshRequested extends ProductEvent {
  const ProductRefreshRequested();
}

class ProductManualSyncRequested extends ProductEvent {
  const ProductManualSyncRequested();
}

class ProductAutoSyncRequested extends ProductEvent {
  const ProductAutoSyncRequested();
}

class ProductConnectivityChanged extends ProductEvent {
  final bool isOnline;

  const ProductConnectivityChanged(this.isOnline);

  @override
  List<Object?> get props => [isOnline];
}
