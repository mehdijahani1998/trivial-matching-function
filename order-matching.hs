-- each order is like a list [id, sell_or_buy ,stock_code, price, quantity]
-- order book is a list of orders
-- each trade is like a list [buy_id, sell_id, stock_code, price, quantity]
-- trades list is a list of trades

import Test.QuickCheck



data Dorder = Dorder {ordid :: Int
                        ,ordtype :: OrderType
                        ,stock_id :: Int
                        ,price :: Float
                        ,quantity :: Int}
                        deriving (Show)

data Trade = SimpleTrade {buy_id :: Int
                            ,sell_id :: Int
                            ,tstock_id :: Int
                            ,tprice :: Float
                            ,tquantity :: Int}
                        deriving (Show)

data OrderType = Sell | Buy | Empty
    deriving(Eq, Show)

instance Arbitrary OrderType where
    arbitrary = elements [Sell, Buy, Empty]

instance Arbitrary Dorder where

   arbitrary = do
     Positive ordid <- arbitrary
     ordtype <- arbitrary
     Positive stock_id <- arbitrary
     Positive price <- arbitrary
     Positive quantity <- arbitrary
     return $ Dorder ordid ordtype stock_id price quantity



monoOrderMatch :: Dorder -> Dorder -> (Dorder, Dorder, Trade)
monoOrderMatch bord sord
    | ordtype bord == Empty = (bord, sord, SimpleTrade 0 0 0 0 0) 
    | ordtype sord == Empty = (bord, sord, SimpleTrade 0 0 0 0 0)
    | ordtype bord == ordtype sord = (bord, sord, SimpleTrade 0 0 0 0 0)
    | stock_id bord /= stock_id sord = let (bid, sid) = (ordid bord ,ordid sord) in
        (bord, sord, SimpleTrade bid sid 0 0 0)
    | price bord < price sord = let (bid, sid) = (ordid bord ,ordid sord) in
        (bord, sord, SimpleTrade bid sid 0 69 0)
    | quantity bord == quantity sord = let nullOrder = Dorder 0 Empty 0 0 0 in
        (nullOrder, nullOrder, resultTrade)
    | otherwise = (remainBuyOrder, remainSellOrder, resultTrade)
    where resultTrade = SimpleTrade (ordid bord) (ordid sord) (stock_id bord) (min (price bord) (price sord)) (min (quantity bord) (quantity sord))
          remainBuyOrder = if quantity bord > quantity sord
              then Dorder (ordid bord) Buy (stock_id bord) (price bord) (quantity bord - quantity sord)
              else Dorder 0 Empty 0 0 0
          remainSellOrder = if quantity bord < quantity sord
              then Dorder (ordid sord) Sell (stock_id sord) (price sord) (quantity sord - quantity bord)
              else Dorder 0 Empty 0 0 0
          nullTrade = SimpleTrade 0 0 0 0 0
          nullOrder = Dorder 0 Empty 0 0 0

processBuyOrder :: Dorder -> [Dorder] -> (Dorder, [Dorder], [Trade])
processBuyOrder (Dorder _ Empty _ _ _) sords = (nullOrder, sords, []) where nullOrder = Dorder 0 Empty 0 0 0
processBuyOrder bord [] = (bord, [], [])
processBuyOrder bord [sord] = let (remBuyOrder, remSellOrder, trade) = monoOrderMatch bord sord in (remBuyOrder, [remSellOrder], [trade])
processBuyOrder bord (sord:sords)
    | ordtype remainBuyOrder == Empty = if ordtype remainSellOrder == Empty
                               then (remainBuyOrder, sords, [trade])
                               else (remainBuyOrder, remainSellOrder:sords, [trade])
    | otherwise = (remainOrder, if ordtype remainSellOrder == Empty 
                                    then remainOrderBook 
                                    else remainSellOrder:remainOrderBook, trade:trades)
    where (remainBuyOrder, remainSellOrder, trade) = monoOrderMatch bord sord
          (remainOrder, remainOrderBook, trades) = processBuyOrder remainBuyOrder sords
          nullOrder = Dorder 0 Empty 0 0 0

getTradesQuantitySum :: [Trade] -> Int
getTradesQuantitySum [] = 0
getTradesQuantitySum [t] = tquantity t
getTradesQuantitySum (t:ts) = tquantity t + getTradesQuantitySum ts

prop_monoMatchQuantity_check buyOrder sellOrder = 
    if tquantity trade > 0 
    then (quantity remainBuyOrder) * (quantity remainSellOrder) == 0
    else quantity remainBuyOrder == quantity buyOrder
    where (remainBuyOrder, remainSellOrder, trade) = monoOrderMatch buyOrder sellOrder

prop_monoMatchType_check buyOrder sellOrder =
    if stock_id buyOrder /= stock_id sellOrder
        then tquantity trade == 0
        else
            if  ordtype buyOrder == ordtype sellOrder || ordtype buyOrder == Empty || ordtype sellOrder == Empty
                then tquantity trade == 0
                else tquantity trade > 0
    where (remainBuyOrder, remainSellOrder, trade) = monoOrderMatch buyOrder sellOrder

prop_quantitySum_check buyOrder orderBook = 
    quantity buyOrder == (getTradesQuantitySum trades) + (quantity remainBuyOrder)
    where (remainBuyOrder, remainOrderBook, trades) = processBuyOrder buyOrder orderBook


prop_quantitySum_check2 buyOrder orderBook = 
    if length orderBook == 0
        then quantity remainBuyOrder == 0
        else quantity remainBuyOrder >= 0
    where (remainBuyOrder, remainOrderBook, trades) = processBuyOrder buyOrder orderBook

