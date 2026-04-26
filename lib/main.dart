import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart' as di;
import 'core/di/injection.dart';
import 'features/products/presentation/bloc/product_bloc.dart';
import 'features/products/presentation/screens/products_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final ProductBloc? productBloc;

  const MyApp({super.key, this.productBloc});

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Products App',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const ProductsScreen(),
    );

    final bloc = productBloc;

    if (bloc != null) {
      return BlocProvider<ProductBloc>.value(
        value: bloc,
        child: app,
      );
    }

    return BlocProvider<ProductBloc>(
      create: (_) => sl<ProductBloc>(),
      child: app,
    );
  }
}
