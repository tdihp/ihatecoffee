browserify -t coffeeify -t brfs --extension='.coffee' ./liner.coffee -o liner.js
# watchify -t coffeeify -t brfs --extension='.coffee' ./liner.coffee -o liner.js