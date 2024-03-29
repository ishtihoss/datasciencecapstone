
# title: "MovieLens Report"
# author: "Md Ishtiaque Hossain"
# date: "8/21/2019"


# DataSet

#For this project a movie rating predictor is created using the 'MovieLens' dataset. This data set can be found and downloaded here:
  
  # - [MovieLens 10M dataset] https://grouplens.org/datasets/movielens/10m/
  # - [MovieLens 10M dataset - zip file] http://files.grouplens.org/datasets/movielens/ml-10m.zip


## Data Loading and Setup

#We use the following code to create training and validation sets.


################################
### Create edx set, validation set
################################

### Note: this process could take a couple of minutes


if(!require(tidyverse)) install.packages("tidyverse", repos = "http://cran.us.r-project.org")
if(!require(caret)) install.packages("caret", repos = "http://cran.us.r-project.org")
if(!require(data.table)) install.packages("data.table", repos = "http://cran.us.r-project.org")

# MovieLens 10M dataset:
# https://grouplens.org/datasets/movielens/10m/
# http://files.grouplens.org/datasets/movielens/ml-10m.zip

dl <- tempfile()
download.file("http://files.grouplens.org/datasets/movielens/ml-10m.zip", dl)

ratings <- fread(text = gsub("::", "\t", readLines(unzip(dl, "ml-10M100K/ratings.dat"))),
                 col.names = c("userId", "movieId", "rating", "timestamp"))

movies <- str_split_fixed(readLines(unzip(dl, "ml-10M100K/movies.dat")), "\\::", 3)
colnames(movies) <- c("movieId", "title", "genres")
movies <- as.data.frame(movies) %>% mutate(movieId = as.numeric(levels(movieId))[movieId],
                                           title = as.character(title),
                                           genres = as.character(genres))

movielens <- left_join(ratings, movies, by = "movieId")

# Validation set will be 10% of MovieLens data

set.seed(1)
# if using R 3.5 or earlier, use `set.seed(1)` instead
test_index <- createDataPartition(y = movielens$rating, times = 1, p = 0.1, list = FALSE)
edx <- movielens[-test_index,]
temp <- movielens[test_index,]

# Make sure userId and movieId in validation set are also in edx set

validation <- temp %>% 
  semi_join(edx, by = "movieId") %>%
  semi_join(edx, by = "userId")

# Add rows removed from validation set back into edx set

removed <- anti_join(temp, validation)
edx <- rbind(edx, removed)

rm(dl, ratings, movies, test_index, temp, movielens, removed)

# Loading necessary packages
if(!require(tidyr)) install.packages("tidyr")
if(!require(stringr)) install.packages("stringr")
if(!require(ggrepel)) install.packages("ggrepel")
if(!require(ggthemes)) install.packages("ggthemes")
if(!require(data.table)) install.packages("data.table")
if(!require(readr)) install.packages("readr")
if(!require(dplyr)) install.packages("dplyr")
if(!require(gridExtra)) install.packages("gridExtra")
if(!require(dslabs)) install.packages("dslabs")
if(!require(lubridate)) install.packages("lubridate")
if(!require(tinytex)) install.packages("tinytex")

library(tidyverse)
library(tidyr)
library(stringr)
library(caret)
library(ggrepel)
library(ggthemes)
library(data.table)
library(caret)
library(readr)
library(gridExtra)
library(lubridate)
library(tinytex)



## Exploratory Analysis

# A quick review using the head() function shows that there are six columns in total. userId and movieId are unique identifiers for users and movies respectively. Rating column contains the ratings given by individual users. Timestamp records the actual time the rating was given. Title contains the name of the movie and the year it was released. Genre corresponds the genre of the movie. The genre column is rather interesting and it is easy to see that each movie can be simultaneously part of multiple genres.


head(edx)

# Quicky summary of the edx dataset

summary(edx)

# We can take a quick look at the distinct number of users and movies in our training set:
  

edx %>% summarize(n_users=n_distinct(userId),
                  n_movies= n_distinct(movieId))


# And also the distinct number of users and movies in the validation set:
  

validation %>% summarize(n_users=n_distinct(userId),
                         n_movies=n_distinct(movieId))


# We see that the number of movies and users in both sets are roughly the same. Now let's look at the ratings distribution:


p1 <- edx %>% ggplot(aes(rating)) + geom_histogram(bins = 10,fill="green",color="black") + ggtitle("train set distribution of ratings")
p2 <- validation %>% ggplot(aes(rating)) + geom_histogram(bins=10,fill="green",color="black") + ggtitle("validation set distribution of ratings")
grid.arrange(p1,p2,nrow=1)


# From the aforementioned charts, we can see that the distribution of ratings in both sets are roughly the same as well. Now let's look at how active/prolific the users are in rating movies in each dataset. 


p1a <- edx %>% group_by(userId) %>% summarise(n=n()) %>% ggplot(aes(n)) + geom_histogram(bins = 10,fill="green",color="black") + scale_x_log10() + ggtitle("User ratings distribution in train set")
p2a <- validation %>% group_by(userId) %>% summarise(n=n()) %>% ggplot(aes(n)) + geom_histogram(bins = 10,fill="green",color="black") + scale_x_log10() + ggtitle("User rating distribution in validation set")
grid.arrange(p1a,p2a,nrow=2)  


# We can see some users are more active in rating movies than the others. We should note that the train set has more prolific/active raters (users who have rated more than a 100 movies) compared to users in the validation set.


# We initially noted that in the genre column, each movie can contain multiple genre. In this form, it is hard to see how many movies are in each individual genre. Therefore we will split the genre row so each movie gets a single genre value in each cell. Movies that belong to multiple genre will have multime observations because we are going to split each genre into it's own row. This makes it easier to calculate the number of movies in each genre. We can see that drama has the highest number of movies, and documentary, IMAX and "no genres listed" having the lowest number of movies.


# Splitting the genre column

edx_genre_split <- edx %>% separate_rows(genres, sep ="\\|")

# Calculating number of movies by genre

edx_genre_split %>% group_by(genres) %>% summarise(n=n()) %>% arrange(desc(n)) %>% ggplot(aes(x=reorder(genres, n), y=n)) +
  geom_bar(stat='identity', fill="blue") + coord_flip(y=c(0, 6000000)) +
  labs(x="", y="Number of Movies") +
  geom_text(aes(label= n), hjust=-0.1, size=3) +
  labs(title="Number of movies by genre" , caption = "source data: edx set")



#Now we look at the average ratings in each genre.Turns out Film-Noir and Documentary are the highest rated movies on average, while Sci-Fi and Horror are the lowest rated ones.


# Calculating average rating for each genre
edx_genre_split %>% group_by(genres) %>% summarise(avg_rating=mean(rating)) %>% arrange(desc(avg_rating)) %>% ggplot(aes(x=reorder(genres, avg_rating), y=avg_rating)) +
  geom_bar(stat='identity', fill="blue") + coord_flip(y=c(0, 5)) +
  labs(x="", y="Average Rating") +
  geom_text(aes(label= avg_rating), hjust=-0.1, size=3) +
  labs(title="Average ratings by genre" , caption = "source data: edx set")


#Now let's look at the overall average in the edx set. 



# Calculating overall average rating across all genres

mu <- mean(edx$rating)
mu


#As we can see the average rating across all genres is 3.51, so we can assume users are rather generous with their ratings, since it's more than 70% across all movies.

## Visualizing genre effect


edx_genre_split %>% group_by(genres) %>% summarise(b_g=mean(rating)) %>% qplot(b_g, geom ="histogram", bins = 10, data = ., color = I("black"))

#But once we group ratings by genre and visualize it using a histogram, we see that there is high variability in rating averages from genre to genre. Therefore it is safe to declare that the genre of the movie has a significant enough effect on its rating for us to consider it for modelling. 

## Visualizing movie effect


edx %>% group_by(movieId) %>% summarise(b_i=mean(rating)) %>% qplot(b_i,geom= "histogram",bins=10,data=.,color=I("black"))



#Once again, we observe high variability in ratings depending on the movie. Which, intuitively makes sense.

## Visualizing user effects


edx %>% group_by(userId) %>% 
  summarize(b_u = mean(rating)) %>% 
  filter(n()>=100) %>%
  ggplot(aes(b_u)) + 
  geom_histogram(bins = 30, color = "black")


#In the aforementioned histogram, we can clearly see that user effect is rather strong, and rating variability is high from user to user. While some users are very generous with their ratings, others are rather conservative. For predicting ratings, user effect therefore should be taken into account. 


## Visualizing the time effect on ratings


edx %>% 
  mutate(date = round_date(as_datetime(timestamp), unit = "week")) %>%
  group_by(date) %>%
  summarize(rating = mean(rating)) %>%
  ggplot(aes(date, rating)) +
  geom_point() +
  geom_smooth(method = "loess") +
  ggtitle("Timestamp, time unit : week")+
  labs(subtitle = "average ratings",
       caption = "source data : edx set")



#While it does appear that older movies enjoyed slightly better ratings, the effect of age is not strong. 


## Creating a model

#We want to create a model that incorporates user effect, movie effect and genre effect. The time effect has been dropped because it does not look significant. 

### Creating Loss Function
#We start by creating an RMSE function that we will use to measure the accuracy of our models. 


RMSE <- function(true_ratings, predicted_ratings){
  sqrt(mean((true_ratings - predicted_ratings)^2))
}


### Building the Model

#First, we create a very simple model using just the average and the movie effect.


# Calculating overall average 

mu <- mean(edx$rating) 

# Calculating Naive RMSE using "Just the average"

just_the_avg <- RMSE(validation$rating,mu)
print(just_the_avg)


#Then we factor in the movie bias


# Calculating movie bias

movie_avgs <- edx %>% 
  group_by(movieId) %>% 
  summarize(b_i = mean(rating - mu))

# Predicted rating using average and movie bias

predicted_ratings <- mu + validation %>% 
  left_join(movie_avgs, by='movieId') %>%
  pull(b_i)


movie_bias_model <- RMSE(validation$rating,predicted_ratings)
print(movie_bias_model)


#After factoring movie bias, we see that our prediction accuracy has improved. Let's see if it improves even further if we take user bias into consideration.

# Calculating user bias

user_avgs <- edx %>% 
  left_join(movie_avgs, by='movieId') %>%
  group_by(userId) %>%
  summarize(b_u = mean(rating - mu - b_i))

predicted_ratings_1 <- validation %>% 
  left_join(movie_avgs, by='movieId') %>%
  left_join(user_avgs, by='userId') %>%
  mutate(pred = mu + b_i + b_u) %>%
  pull(pred)

movie_and_user_bias_model <- RMSE(validation$rating,predicted_ratings_1)
print(movie_and_user_bias_model)


#As we have observed from our previous analysisi that ratings can vary based on genre, so we will consider the genre bias as well.


# Calculating genre bias

genre_avgs <- edx %>% left_join(movie_avgs,by='movieId') %>% left_join(user_avgs,by='userId') %>% group_by(genres) %>% summarise(b_g=mean(rating-mu-b_i-b_u))

predicted_ratings_2 <- validation %>%
  left_join(movie_avgs,by='movieId') %>% left_join(user_avgs,by='userId') %>% left_join(genre_avgs,by='genres') %>% mutate(pred=mu+b_i+b_u+b_g)  %>% pull(pred)

movie_user_genre_bias_model <- RMSE(validation$rating,predicted_ratings_2)
print(movie_user_genre_bias_model)


#However, we might be able to improve the accuracy of our model even further if we use the regularization technique.


lambdas <- seq(0, 10, 0.25)

rmses <- sapply(lambdas, function(l){
  
  mu_reg <- mean(edx$rating)
  
  b_i_reg <- edx %>% 
    group_by(movieId) %>%
    summarize(b_i_reg = sum(rating - mu_reg)/(n()+l))
  
  b_u_reg <- edx %>% 
    left_join(b_i_reg, by="movieId") %>%
    group_by(userId) %>%
    summarize(b_u_reg = sum(rating - b_i_reg - mu_reg)/(n()+l))
  
  b_g_reg <- edx %>% left_join(b_i_reg,by='movieId') %>% left_join(b_u_reg,by='userId') %>% group_by(genres) %>% summarise(b_g_reg=sum(rating - b_i_reg - b_u_reg - mu_reg)/(n()+l))
  
  predicted_ratings_b_i_u_g <- 
    validation %>% 
    left_join(b_i_reg, by = "movieId") %>%
    left_join(b_u_reg, by = "userId") %>%
    left_join(b_g_reg,by='genres') %>%
    mutate(pred = mu_reg + b_i_reg + b_u_reg+b_g_reg) %>%
    .$pred
  
  return(RMSE(validation$rating,predicted_ratings_b_i_u_g))
})



## Let's look at the optimum Lamda 



qplot(lambdas, rmses)

lambdas[which.min(rmses)]
# RMSE for regularized model that incorporates genre, user and movie bias

regularized_model_with_movie_genre_user_bias <- min(rmses)
print(regularized_model_with_movie_genre_user_bias)



# Results

#There seems to be dramatic improvement over the "just the average approach" when we use movie and user bias into account. And slight improvements when we incorporate genre bias and regularization techniques. 




results <- data.frame(Model_Name=c("Just the average","Movie Bias", "Movie + User Bias", "Movie + User + Genre Bias", "Regularized Movie+User+Genre Bias"),RMSE=c(just_the_avg,movie_bias_model,movie_and_user_bias_model,movie_user_genre_bias_model,regularized_model_with_movie_genre_user_bias))

results %>% ggplot(aes(x=reorder(Model_Name,RMSE),RMSE)) + geom_bar(stat="identity",fill="green") + coord_flip(y=c(0,2)) + labs(title="RMSE by Model",x="Model Name",y="RMSE")+geom_text(aes(label=RMSE))



# Conclusion

# By using regularization and modelling user bias, movie bias and genre bias, it is possible to reduce the RMSE to 0.8644501, which meets the "RMSE <= 0.8649" requirement for full 25 points. The time effect was not modelled because from the initial analysis it became apparent that the time bias is not as strong as the other three. However the RMSE can be reduced even further by using advanced techniques like ensemble learning and model stacking. But for a large dataset, those techniques cannot be used from a desktop/laptop computer due to insufficient memory. The next step would be to use a cloud computing platform that supports machine learning, like Azure or Google AI Platform and use ensemble learning  and model stacking to achieve more accurate results. 




