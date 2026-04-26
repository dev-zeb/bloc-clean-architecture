import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../../features/products/data/datasources/product_local_data_source.dart';
import '../../features/products/data/datasources/product_remote_data_source.dart';
import '../../features/products/data/repositories/product_repository_impl.dart';
import '../../features/products/domain/repositories/product_repository.dart';
import '../../features/products/domain/usecase/get_products.dart';
import '../../features/products/presentation/bloc/product_bloc.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../network/network_info_impl.dart';

final sl = GetIt.instance;

Future<void> init() async {
  await Hive.initFlutter();

  final productsBox = await Hive.openBox<Map>(AppConstants.productsBox);
  final productsMetaBox = await Hive.openBox<Map>(AppConstants.productsMetaBox);

  sl.registerLazySingleton<Box<Map>>(
    () => productsBox,
    instanceName: AppConstants.productsBox,
  );

  sl.registerLazySingleton<Box<Map>>(
    () => productsMetaBox,
    instanceName: AppConstants.productsMetaBox,
  );

  sl.registerLazySingleton<Dio>(() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );

    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));

    return dio;
  });

  sl.registerLazySingleton<ApiClient>(() => ApiClient(sl<Dio>()));

  sl.registerLazySingleton<InternetConnectionChecker>(
    () => InternetConnectionChecker.instance,
  );

  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(sl<InternetConnectionChecker>()),
  );

  sl.registerLazySingleton<ProductRemoteDataSource>(
    () => ProductRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<ProductLocalDataSource>(
    () => ProductLocalDataSourceImpl(
      productsBox: sl<Box<Map>>(instanceName: AppConstants.productsBox),
      metaBox: sl<Box<Map>>(instanceName: AppConstants.productsMetaBox),
    ),
  );

  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(
      remoteDataSource: sl<ProductRemoteDataSource>(),
      localDataSource: sl<ProductLocalDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  sl.registerLazySingleton<GetProducts>(
    () => GetProducts(sl<ProductRepository>()),
  );

  sl.registerFactory<ProductBloc>(
    () => ProductBloc(
      getProducts: sl<GetProducts>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );
}
