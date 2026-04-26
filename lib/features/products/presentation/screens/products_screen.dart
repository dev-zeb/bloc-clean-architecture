import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/product_bloc.dart';
import '../bloc/product_event.dart';
import '../bloc/product_state.dart';
import '../widgets/product_card.dart';
import 'mock_login_page.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ScrollController _scrollController = ScrollController();

  bool _shouldRequestNextPageAfterReconnect = false;
  int _lastHandledNotificationId = 0;

  @override
  void initState() {
    super.initState();

    context.read<ProductBloc>().add(const ProductStarted());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - 300) {
      context.read<ProductBloc>().add(const ProductNextPageRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductBloc, ProductState>(
      listenWhen: (previous, current) {
        return previous.status != current.status ||
            previous.notificationId != current.notificationId ||
            previous.isRefreshing != current.isRefreshing ||
            previous.isLoadingMore != current.isLoadingMore ||
            previous.hasReachedMax != current.hasReachedMax;
      },
      listener: (context, state) {
        if (state.status == ProductStatus.unauthorized) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MockLoginPage()),
          );
          return;
        }

        final hasNewNotice = state.notificationId > 0 &&
            state.notificationId != _lastHandledNotificationId &&
            state.notificationMessage.isNotEmpty;

        if (hasNewNotice) {
          _lastHandledNotificationId = state.notificationId;
          _showNotice(context, state);
        }

        if (hasNewNotice &&
            state.notificationType == ProductNoticeType.connectionRestored) {
          _shouldRequestNextPageAfterReconnect = true;
          return;
        }

        if (_shouldRequestNextPageAfterReconnect) {
          _requestNextPageAfterReconnectIfNeeded(state);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Products'),
          actions: [
            BlocBuilder<ProductBloc, ProductState>(
              buildWhen: (previous, current) {
                return previous.isOnline != current.isOnline ||
                    previous.isRefreshing != current.isRefreshing;
              },
              builder: (context, state) {
                return Row(
                  children: [
                    Tooltip(
                      message: _connectionTooltip(state),
                      child: Icon(
                        _connectionIcon(state),
                        color: _connectionColor(state),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sync',
                      onPressed: state.isRefreshing
                          ? null
                          : () {
                              context.read<ProductBloc>().add(
                                    const ProductManualSyncRequested(),
                                  );
                            },
                      icon: state.isRefreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<ProductBloc, ProductState>(
          builder: (context, state) {
            if (state.status == ProductStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.status == ProductStatus.empty) {
              return const Center(child: Text('No products found.'));
            }

            if (state.status == ProductStatus.failure &&
                state.products.isEmpty) {
              return _ErrorView(message: state.message);
            }

            return Column(
              children: [
                _PaginationInfo(state: state),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      context.read<ProductBloc>().add(
                            const ProductRefreshRequested(),
                          );
                    },
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: state.products.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index >= state.products.length) {
                          if (state.isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (state.hasReachedMax) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text('You have reached the end.'),
                              ),
                            );
                          }

                          if (!state.isOnline && state.hasMoreProducts) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  'Reconnect to load more products.',
                                ),
                              ),
                            );
                          }

                          if (state.status == ProductStatus.failure) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(child: Text(state.message)),
                            );
                          }

                          return const SizedBox.shrink();
                        }

                        return ProductCard(product: state.products[index]);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _showNotice(BuildContext context, ProductState state) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(state.notificationMessage),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _noticeColor(context, state.notificationType),
      ),
    );
  }

  void _requestNextPageAfterReconnectIfNeeded(ProductState observedState) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final bloc = context.read<ProductBloc>();
      final state = bloc.state;

      if (state != observedState ||
          state.status != ProductStatus.success ||
          !state.isOnline ||
          state.isRefreshing ||
          state.isLoadingMore ||
          state.hasReachedMax) {
        return;
      }

      final position = _scrollController.position;
      _shouldRequestNextPageAfterReconnect = false;

      if (position.pixels >= position.maxScrollExtent - 300) {
        bloc.add(const ProductNextPageRequested());
      }
    });
  }

  IconData _connectionIcon(ProductState state) {
    if (!state.isOnline) return Icons.wifi_off;
    return Icons.wifi;
  }

  Color _connectionColor(ProductState state) {
    if (!state.isOnline) return Colors.red;
    return Colors.green;
  }

  String _connectionTooltip(ProductState state) {
    if (!state.isOnline) return 'Offline';
    return 'Online';
  }

  Color? _noticeColor(BuildContext context, ProductNoticeType type) {
    switch (type) {
      case ProductNoticeType.connectionLost:
      case ProductNoticeType.fetchFailed:
        return Theme.of(context).colorScheme.error;
      case ProductNoticeType.connectionRestored:
        return Colors.green.shade700;
      case ProductNoticeType.none:
        return null;
    }
  }
}

class _PaginationInfo extends StatelessWidget {
  final ProductState state;

  const _PaginationInfo({required this.state});

  @override
  Widget build(BuildContext context) {
    final cacheLabel = state.isFromCache ? ' • Cached' : '';

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'Showing ${state.products.length} of ${state.totalItems} products • '
        'Page ${state.currentPage} of ${state.totalPages}$cacheLabel',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                context.read<ProductBloc>().add(
                      const ProductManualSyncRequested(),
                    );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';

// import '../bloc/product_bloc.dart';
// import '../bloc/product_event.dart';
// import '../bloc/product_state.dart';
// import '../widgets/product_card.dart';
// import 'mock_login_page.dart';

// class ProductsScreen extends StatefulWidget {
//   const ProductsScreen({super.key});

//   @override
//   State<ProductsScreen> createState() => _ProductsScreenState();
// }

// class _ProductsScreenState extends State<ProductsScreen> {
//   final ScrollController _scrollController = ScrollController();
//   bool _shouldRequestNextPageAfterReconnect = false;

//   @override
//   void initState() {
//     super.initState();

//     context.read<ProductBloc>().add(const ProductStarted());

//     _scrollController.addListener(_onScroll);
//   }

//   void _onScroll() {
//     if (!_scrollController.hasClients) return;

//     final position = _scrollController.position;

//     if (position.pixels >= position.maxScrollExtent - 300) {
//       context.read<ProductBloc>().add(const ProductNextPageRequested());
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return BlocListener<ProductBloc, ProductState>(
//       listenWhen: (previous, current) {
//         return previous.status != current.status ||
//             previous.notificationId != current.notificationId ||
//             previous.isOnline != current.isOnline ||
//             previous.isRefreshing != current.isRefreshing ||
//             previous.isLoadingMore != current.isLoadingMore ||
//             previous.hasReachedMax != current.hasReachedMax;
//       },
//       listener: (context, state) {
//         if (state.status == ProductStatus.unauthorized) {
//           Navigator.of(context).pushReplacement(
//             MaterialPageRoute(builder: (_) => const MockLoginPage()),
//           );
//           return;
//         }

//         if (state.notificationMessage.isNotEmpty) {
//           _showNotice(context, state);
//         }

//         if (state.notificationType == ProductNoticeType.connectionRestored) {
//           _shouldRequestNextPageAfterReconnect = true;
//           return;
//         }

//         if (_shouldRequestNextPageAfterReconnect) {
//           _requestNextPageAfterReconnectIfNeeded(state);
//         }
//       },
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Products'),
//           actions: [
//             BlocBuilder<ProductBloc, ProductState>(
//               buildWhen: (previous, current) {
//                 return previous.isOnline != current.isOnline ||
//                     previous.isRefreshing != current.isRefreshing;
//               },
//               builder: (context, state) {
//                 return Row(
//                   children: [
//                     Tooltip(
//                       message: _connectionTooltip(state),
//                       child: Icon(
//                         _connectionIcon(state),
//                         color: _connectionColor(state),
//                       ),
//                     ),
//                     IconButton(
//                       tooltip: 'Sync',
//                       onPressed: state.isRefreshing
//                           ? null
//                           : () {
//                               context.read<ProductBloc>().add(
//                                     const ProductManualSyncRequested(),
//                                   );
//                             },
//                       icon: state.isRefreshing
//                           ? const SizedBox(
//                               width: 18,
//                               height: 18,
//                               child: CircularProgressIndicator(strokeWidth: 2),
//                             )
//                           : const Icon(Icons.sync),
//                     ),
//                   ],
//                 );
//               },
//             ),
//           ],
//         ),
//         body: BlocBuilder<ProductBloc, ProductState>(
//           builder: (context, state) {
//             if (state.status == ProductStatus.loading) {
//               return const Center(child: CircularProgressIndicator());
//             }

//             if (state.status == ProductStatus.empty) {
//               return const Center(child: Text('No products found.'));
//             }

//             if (state.status == ProductStatus.failure &&
//                 state.products.isEmpty) {
//               return _ErrorView(message: state.message);
//             }

//             return Column(
//               children: [
//                 _PaginationInfo(state: state),
//                 Expanded(
//                   child: RefreshIndicator(
//                     onRefresh: () async {
//                       context.read<ProductBloc>().add(
//                             const ProductRefreshRequested(),
//                           );
//                     },
//                     child: ListView.separated(
//                       controller: _scrollController,
//                       padding: const EdgeInsets.all(16),
//                       itemCount: state.products.length + 1,
//                       separatorBuilder: (_, __) => const SizedBox(height: 12),
//                       itemBuilder: (context, index) {
//                         if (index >= state.products.length) {
//                           if (state.isLoadingMore) {
//                             return const Padding(
//                               padding: EdgeInsets.all(16),
//                               child: Center(child: CircularProgressIndicator()),
//                             );
//                           }

//                           if (state.hasReachedMax) {
//                             return const Padding(
//                               padding: EdgeInsets.all(16),
//                               child: Center(
//                                 child: Text('You have reached the end.'),
//                               ),
//                             );
//                           }

//                           if (!state.isOnline && state.hasMoreProducts) {
//                             return const Padding(
//                               padding: EdgeInsets.all(16),
//                               child: Center(
//                                 child: Text(
//                                   'Reconnect to load more products.',
//                                 ),
//                               ),
//                             );
//                           }

//                           if (state.status == ProductStatus.failure) {
//                             return Padding(
//                               padding: const EdgeInsets.all(16),
//                               child: Center(child: Text(state.message)),
//                             );
//                           }

//                           return const SizedBox.shrink();
//                         }

//                         return ProductCard(product: state.products[index]);
//                       },
//                     ),
//                   ),
//                 ),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _scrollController
//       ..removeListener(_onScroll)
//       ..dispose();
//     super.dispose();
//   }

//   void _showNotice(BuildContext context, ProductState state) {
//     final messenger = ScaffoldMessenger.of(context);

//     messenger.clearSnackBars();
//     messenger.showSnackBar(
//       SnackBar(
//         content: Text(state.notificationMessage),
//         behavior: SnackBarBehavior.floating,
//         backgroundColor: _noticeColor(context, state.notificationType),
//       ),
//     );
//   }

//   void _requestNextPageAfterReconnectIfNeeded(ProductState observedState) {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted || !_scrollController.hasClients) return;

//       final bloc = context.read<ProductBloc>();
//       final state = bloc.state;

//       if (state != observedState ||
//           state.status != ProductStatus.success ||
//           !state.isOnline ||
//           state.isRefreshing ||
//           state.isLoadingMore ||
//           state.hasReachedMax) {
//         return;
//       }

//       final position = _scrollController.position;
//       _shouldRequestNextPageAfterReconnect = false;

//       if (position.pixels >= position.maxScrollExtent - 300) {
//         bloc.add(const ProductNextPageRequested());
//       }
//     });
//   }

//   IconData _connectionIcon(ProductState state) {
//     if (!state.isOnline) return Icons.wifi_off;
//     return Icons.wifi;
//   }

//   Color _connectionColor(ProductState state) {
//     if (!state.isOnline) return Colors.red;
//     return Colors.green;
//   }

//   String _connectionTooltip(ProductState state) {
//     if (!state.isOnline) return 'Offline';
//     return 'Online';
//   }

//   Color? _noticeColor(BuildContext context, ProductNoticeType type) {
//     switch (type) {
//       case ProductNoticeType.connectionLost:
//       case ProductNoticeType.fetchFailed:
//         return Theme.of(context).colorScheme.error;
//       case ProductNoticeType.connectionRestored:
//         return Colors.green.shade700;
//       case ProductNoticeType.none:
//         return null;
//     }
//   }
// }

// class _PaginationInfo extends StatelessWidget {
//   final ProductState state;

//   const _PaginationInfo({required this.state});

//   @override
//   Widget build(BuildContext context) {
//     final cacheLabel = state.isFromCache ? ' • Cached' : '';

//     return Container(
//       width: double.infinity,
//       color: Theme.of(context).colorScheme.surfaceContainerHighest,
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//       child: Text(
//         'Showing ${state.products.length} of ${state.totalItems} products • '
//         'Page ${state.currentPage} of ${state.totalPages}$cacheLabel',
//         style: Theme.of(context).textTheme.bodySmall,
//       ),
//     );
//   }
// }

// class _ErrorView extends StatelessWidget {
//   final String message;

//   const _ErrorView({required this.message});

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.error_outline, size: 48),
//             const SizedBox(height: 12),
//             Text(message, textAlign: TextAlign.center),
//             const SizedBox(height: 16),
//             ElevatedButton.icon(
//               onPressed: () {
//                 context.read<ProductBloc>().add(
//                       const ProductManualSyncRequested(),
//                     );
//               },
//               icon: const Icon(Icons.refresh),
//               label: const Text('Try again'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
