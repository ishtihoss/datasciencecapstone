# Creating RMSE Function

RMSE <- function(true_ratings, predicted_ratings){
  sqrt(mean((true_ratings - predicted_ratings)^2))
}

# One-hot encoding

cbind(small_edx, mtabulate(strsplit(small_edx$genres, ","))) %>% View()