require 'redis'

$redis = Redis.new(url: ENV.fetch("REDISCLOUD_URL", "redis://localhost:6379"))
$rollout = Rollout.new($redis)
