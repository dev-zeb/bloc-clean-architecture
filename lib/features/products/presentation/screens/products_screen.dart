import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/product_bloc.dart';
import '../bloc/product_event.dart';
import '../bloc/product_state.dart';
import '../widgets/offline_banner.dart';
import '../widgets/product_card.dart';
import 'mock_login_page.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ScrollController _scrollController = ScrollController();

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
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == ProductStatus.unauthorized) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MockLoginPage()),
          );
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
                    Icon(
                      state.isOnline ? Icons.wifi : Icons.wifi_off,
                      color: state.isOnline ? Colors.green : Colors.red,
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
                if (!state.isOnline || state.isFromCache)
                  OfflineBanner(isOnline: state.isOnline),

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
}

class _PaginationInfo extends StatelessWidget {
  final ProductState state;

  const _PaginationInfo({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'Showing ${state.products.length} of ${state.totalItems} products • '
        'Page ${state.currentPage} of ${state.totalPages}',
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
