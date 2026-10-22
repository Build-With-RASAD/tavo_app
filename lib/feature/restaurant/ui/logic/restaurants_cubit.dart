import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tavo/feature/home/data/models/restaurant_model.dart';

import 'package:tavo/feature/restaurant/data/repo/restaurants_repo.dart';
import 'restaurants_state.dart';

class RestaurantsCubit extends Cubit<RestaurantsState> {
  final RestaurantsRepo _restaurantsRepo;
  final String _locale;

  RestaurantsCubit(this._restaurantsRepo, {this._locale = 'ar'})
      : super(const RestaurantsState());

  Future<void> loadRestaurants() async {
    emit(state.copyWith(loading: true, clearError: true));
    
    try {
      final response = await _restaurantsRepo.getRestaurants();
      
      if (response.success) {
        emit(state.copyWith(
          restaurants: response.data,
          filteredRestaurants: response.data,
          loading: false,
        ));
      } else {
        emit(state.copyWith(
          loading: false,
          error: response.message ?? 'Failed to load restaurants',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        error: e.toString(),
      ));
    }
  }

  void applyFilters({String? category, double? minRating}) {
    final categoryId = _getCategoryIdByName(category);
    
    emit(state.copyWith(
      selectedCategory: category,
      selectedCategoryId: categoryId,
      minRating: minRating,
      clearCategory: category == null,
      clearRating: minRating == null,
    ));
    
    _filterRestaurants();
  }

  void selectCategory(String? categoryName) {
    final categoryId = _getCategoryIdByName(categoryName);
    
    emit(state.copyWith(
      selectedCategory: categoryName,
      selectedCategoryId: categoryId,
      clearCategory: categoryName == null,
    ));
    
    _filterRestaurants();
  }

  void setMinRating(double? rating) {
    emit(state.copyWith(
      minRating: rating,
      clearRating: rating == null,
    ));
    
    _filterRestaurants();
  }

  void clearCategory() {
    emit(state.copyWith(clearCategory: true));
    _filterRestaurants();
  }

  void clearMinRating() {
    emit(state.copyWith(clearRating: true));
    _filterRestaurants();
  }

  void clearAllFilters() {
    emit(state.copyWith(
      clearCategory: true,
      clearRating: true,
      filteredRestaurants: state.restaurants,
    ));
  }

  void _filterRestaurants() {
    List<RestaurantModel> filtered = List.from(state.restaurants);

    if (state.selectedCategory != null) {
      filtered = filtered.where((r) {
        return r.categories.any((c) => c.getName(_locale) == state.selectedCategory);
      }).toList();
    }

    if (state.minRating != null) {
      filtered = filtered.where((r) => r.ratingsAverage >= state.minRating!).toList();
    }

    emit(state.copyWith(filteredRestaurants: filtered));
  }

  String? _getCategoryIdByName(String? categoryName) {
    if (categoryName == null) return null;
    
    for (final restaurant in state.restaurants) {
      for (final category in restaurant.categories) {
        if (category.getName(_locale) == categoryName) {
          return category.id;
        }
      }
    }
    return null;
  }

  List<String> getAllCategories() {
    final Set<String> categories = {};
    
    for (final restaurant in state.restaurants) {
      for (final category in restaurant.categories) {
        categories.add(category.getName(_locale));
      }
    }
    
    return categories.toList();
  }

  Future<void> refresh() async {
    await loadRestaurants();
    
    if (state.hasAnyFilter) {
      _filterRestaurants();
    }
  }
}