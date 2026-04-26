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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProductBloc>(
      create: (_) => sl<ProductBloc>(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Products App',
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
        ),
        home: const ProductsScreen(),
      ),
    );
  }
}
