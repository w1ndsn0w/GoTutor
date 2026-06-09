import Foundation

enum TutorialLessonAction: Equatable {
    case placeStone
    case inspectPoint
    case forbiddenPoint
    case watchDemo
}

struct TutorialBoardStone: Hashable, Identifiable {
    let point: Point
    let stone: Stone

    var id: Point { point }
}

struct TutorialDemoFrame: Equatable {
    let stones: [TutorialBoardStone]
    let lastMove: Point?
    let highlightPoints: [Point]
    let blackTerritory: [Point]
    let whiteTerritory: [Point]
    let caption: String

    init(
        stones: [TutorialBoardStone],
        lastMove: Point? = nil,
        highlightPoints: [Point] = [],
        blackTerritory: [Point] = [],
        whiteTerritory: [Point] = [],
        caption: String
    ) {
        self.stones = stones
        self.lastMove = lastMove
        self.highlightPoints = highlightPoints
        self.blackTerritory = blackTerritory
        self.whiteTerritory = whiteTerritory
        self.caption = caption
    }
}

struct TutorialLesson: Identifiable, Equatable {
    let id: Int
    let title: String
    let explanation: String
    let task: String
    let initialStones: [TutorialBoardStone]
    let currentPlayer: Stone
    let correctPoint: Point?
    let action: TutorialLessonAction
    let wrongHint: String
    let successFeedback: String
    let demoFrames: [TutorialDemoFrame]

    init(
        id: Int,
        title: String,
        explanation: String,
        task: String,
        initialStones: [TutorialBoardStone],
        currentPlayer: Stone,
        correctPoint: Point? = nil,
        action: TutorialLessonAction,
        wrongHint: String,
        successFeedback: String,
        demoFrames: [TutorialDemoFrame] = []
    ) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.task = task
        self.initialStones = initialStones
        self.currentPlayer = currentPlayer
        self.correctPoint = correctPoint
        self.action = action
        self.wrongHint = wrongHint
        self.successFeedback = successFeedback
        self.demoFrames = demoFrames
    }
}

extension TutorialLesson {
    static let all: [TutorialLesson] = [
        TutorialLesson(
            id: 1,
            title: "棋盘与落子",
            explanation: "围棋下在交叉点上，黑先白后，双方轮流落子。",
            task: "请把黑棋下在棋盘中央的天元。",
            initialStones: [],
            currentPlayer: .black,
            correctPoint: Point(r: 4, c: 4),
            action: .placeStone,
            wrongHint: "找棋盘最中央的交叉点，下在格线相交处。",
            successFeedback: "很好，棋子应该落在交叉点上。下一手会轮到白棋。"
        ),
        TutorialLesson(
            id: 2,
            title: "什么是气",
            explanation: "一颗棋子上下左右相邻的空交叉点，叫作它的气。",
            task: "点一下黑棋最后一口气的位置。",
            initialStones: [
                .init(point: Point(r: 4, c: 4), stone: .black),
                .init(point: Point(r: 3, c: 4), stone: .white),
                .init(point: Point(r: 4, c: 3), stone: .white),
                .init(point: Point(r: 5, c: 4), stone: .white)
            ],
            currentPlayer: .black,
            correctPoint: Point(r: 4, c: 5),
            action: .inspectPoint,
            wrongHint: "气只数上下左右，不数斜线。找黑棋旁边唯一的空点。",
            successFeedback: "对，这个空点就是黑棋还能呼吸的最后一口气。"
        ),
        TutorialLesson(
            id: 3,
            title: "如何提子",
            explanation: "把对方一块棋的最后一口气堵住，就能把它从棋盘上提走。",
            task: "黑棋落在白棋最后一口气上，提掉白子。",
            initialStones: [
                .init(point: Point(r: 4, c: 4), stone: .white),
                .init(point: Point(r: 3, c: 4), stone: .black),
                .init(point: Point(r: 4, c: 3), stone: .black),
                .init(point: Point(r: 5, c: 4), stone: .black)
            ],
            currentPlayer: .black,
            correctPoint: Point(r: 4, c: 5),
            action: .placeStone,
            wrongHint: "白棋只剩右边这一口气，黑棋要堵住它。",
            successFeedback: "漂亮，白子没有气了，被黑棋提走。"
        ),
        TutorialLesson(
            id: 4,
            title: "连接与断点",
            explanation: "相邻的己方棋子会连成一块；断点常常决定棋形强弱。",
            task: "请把两颗黑棋连接起来。",
            initialStones: [
                .init(point: Point(r: 4, c: 3), stone: .black),
                .init(point: Point(r: 4, c: 5), stone: .black),
                .init(point: Point(r: 3, c: 4), stone: .white),
                .init(point: Point(r: 5, c: 4), stone: .white)
            ],
            currentPlayer: .black,
            correctPoint: Point(r: 4, c: 4),
            action: .placeStone,
            wrongHint: "两颗黑棋之间的空点，就是最直接的连接点。",
            successFeedback: "连上了。连在一起的棋共享气，也更难被分断。"
        ),
        TutorialLesson(
            id: 5,
            title: "禁入点",
            explanation: "如果落子后自己没有气，又没有提掉对方棋，这手就是自杀禁手。",
            task: "点一下白棋不能下的禁入点。",
            initialStones: [
                .init(point: Point(r: 3, c: 4), stone: .black),
                .init(point: Point(r: 4, c: 3), stone: .black),
                .init(point: Point(r: 4, c: 5), stone: .black),
                .init(point: Point(r: 5, c: 4), stone: .black)
            ],
            currentPlayer: .white,
            correctPoint: Point(r: 4, c: 4),
            action: .forbiddenPoint,
            wrongHint: "看四颗黑棋围住的空点，白棋下进去会立刻没有气。",
            successFeedback: "对，这里对白棋是禁入点，因为下完没有任何气。"
        ),
        TutorialLesson(
            id: 6,
            title: "劫的概念",
            explanation: "劫会让双方反复提同一颗子。规则要求不能立刻提回。",
            task: "按下一步演示，观察为什么要先在别处下一手。",
            initialStones: [
                .init(point: Point(r: 2, c: 3), stone: .black),
                .init(point: Point(r: 3, c: 2), stone: .black),
                .init(point: Point(r: 4, c: 3), stone: .black),
                .init(point: Point(r: 3, c: 3), stone: .white),
                .init(point: Point(r: 2, c: 4), stone: .white),
                .init(point: Point(r: 3, c: 5), stone: .white),
                .init(point: Point(r: 4, c: 4), stone: .white)
            ],
            currentPlayer: .black,
            action: .watchDemo,
            wrongHint: "",
            successFeedback: "劫的关键不是“不能提”，而是“不能马上提回”。",
            demoFrames: [
                TutorialDemoFrame(
                    stones: [
                        .init(point: Point(r: 2, c: 3), stone: .black),
                        .init(point: Point(r: 3, c: 2), stone: .black),
                        .init(point: Point(r: 4, c: 3), stone: .black),
                        .init(point: Point(r: 3, c: 3), stone: .white),
                        .init(point: Point(r: 2, c: 4), stone: .white),
                        .init(point: Point(r: 3, c: 5), stone: .white),
                        .init(point: Point(r: 4, c: 4), stone: .white)
                    ],
                    highlightPoints: [Point(r: 3, c: 4)],
                    caption: "黑棋可以下在蓝点，提掉只有一口气的白子。"
                ),
                TutorialDemoFrame(
                    stones: [
                        .init(point: Point(r: 2, c: 3), stone: .black),
                        .init(point: Point(r: 3, c: 2), stone: .black),
                        .init(point: Point(r: 4, c: 3), stone: .black),
                        .init(point: Point(r: 3, c: 4), stone: .black),
                        .init(point: Point(r: 2, c: 4), stone: .white),
                        .init(point: Point(r: 3, c: 5), stone: .white),
                        .init(point: Point(r: 4, c: 4), stone: .white)
                    ],
                    lastMove: Point(r: 3, c: 4),
                    highlightPoints: [Point(r: 3, c: 3)],
                    caption: "黑提白后，白棋很想马上下回蓝点，反提这颗黑子。"
                ),
                TutorialDemoFrame(
                    stones: [
                        .init(point: Point(r: 2, c: 3), stone: .black),
                        .init(point: Point(r: 3, c: 2), stone: .black),
                        .init(point: Point(r: 4, c: 3), stone: .black),
                        .init(point: Point(r: 3, c: 3), stone: .white),
                        .init(point: Point(r: 2, c: 4), stone: .white),
                        .init(point: Point(r: 3, c: 5), stone: .white),
                        .init(point: Point(r: 4, c: 4), stone: .white)
                    ],
                    lastMove: Point(r: 3, c: 3),
                    highlightPoints: [Point(r: 3, c: 4)],
                    caption: "如果允许马上反提，棋盘会回到第一步前，双方会无限循环。"
                ),
                TutorialDemoFrame(
                    stones: [
                        .init(point: Point(r: 2, c: 3), stone: .black),
                        .init(point: Point(r: 3, c: 2), stone: .black),
                        .init(point: Point(r: 4, c: 3), stone: .black),
                        .init(point: Point(r: 3, c: 4), stone: .black),
                        .init(point: Point(r: 2, c: 4), stone: .white),
                        .init(point: Point(r: 3, c: 5), stone: .white),
                        .init(point: Point(r: 4, c: 4), stone: .white),
                        .init(point: Point(r: 6, c: 6), stone: .white)
                    ],
                    lastMove: Point(r: 6, c: 6),
                    highlightPoints: [Point(r: 3, c: 3)],
                    caption: "所以白棋要先在别处下一手，再回来争这个劫。"
                )
            ]
        ),
        TutorialLesson(
            id: 7,
            title: "真眼与假眼",
            explanation: "真眼不能被对方轻易填掉；假眼旁边有断点，会被破掉。",
            task: "按演示看：为什么右边看起来像眼，却不是真的眼。",
            initialStones: [
                .init(point: Point(r: 2, c: 2), stone: .black),
                .init(point: Point(r: 2, c: 3), stone: .black),
                .init(point: Point(r: 2, c: 4), stone: .black),
                .init(point: Point(r: 3, c: 2), stone: .black),
                .init(point: Point(r: 3, c: 4), stone: .black),
                .init(point: Point(r: 4, c: 2), stone: .black),
                .init(point: Point(r: 4, c: 3), stone: .black),
                .init(point: Point(r: 4, c: 4), stone: .black),
                .init(point: Point(r: 2, c: 6), stone: .black),
                .init(point: Point(r: 3, c: 5), stone: .black),
                .init(point: Point(r: 3, c: 7), stone: .black),
                .init(point: Point(r: 4, c: 6), stone: .black),
                .init(point: Point(r: 2, c: 5), stone: .white)
            ],
            currentPlayer: .black,
            action: .watchDemo,
            wrongHint: "",
            successFeedback: "真眼要看周围和斜角是否稳固；假眼会因为断点塌掉。",
            demoFrames: [
                TutorialDemoFrame(
                    stones: [
                        .init(point: Point(r: 2, c: 2), stone: .black),
                        .init(point: Point(r: 2, c: 3), stone: .black),
                        .init(point: Point(r: 2, c: 4), stone: .black),
                        .init(point: Point(r: 3, c: 2), stone: .black),
                        .init(point: Point(r: 3, c: 4), stone: .black),
                        .init(point: Point(r: 4, c: 2), stone: .black),
                        .init(point: Point(r: 4, c: 3), stone: .black),
                        .init(point: Point(r: 4, c: 4), stone: .black)
                    ],
                    highlightPoints: [Point(r: 3, c: 3)],
                    caption: "左边这个空点被黑棋稳稳包住，对方下进去会没气。"
                ),
                TutorialDemoFrame(
                    stones: [
                        .init(point: Point(r: 2, c: 2), stone: .black),
                        .init(point: Point(r: 2, c: 3), stone: .black),
                        .init(point: Point(r: 2, c: 4), stone: .black),
                        .init(point: Point(r: 3, c: 2), stone: .black),
                        .init(point: Point(r: 3, c: 4), stone: .black),
                        .init(point: Point(r: 4, c: 2), stone: .black),
                        .init(point: Point(r: 4, c: 3), stone: .black),
                        .init(point: Point(r: 4, c: 4), stone: .black),
                        .init(point: Point(r: 2, c: 6), stone: .black),
                        .init(point: Point(r: 3, c: 5), stone: .black),
                        .init(point: Point(r: 3, c: 7), stone: .black),
                        .init(point: Point(r: 4, c: 6), stone: .black),
                        .init(point: Point(r: 2, c: 5), stone: .white),
                        .init(point: Point(r: 4, c: 7), stone: .white)
                    ],
                    highlightPoints: [Point(r: 3, c: 6), Point(r: 2, c: 5), Point(r: 4, c: 7)],
                    caption: "右边空点旁边有两个斜角被白棋占住，黑棋连接不牢。"
                ),
                TutorialDemoFrame(
                    stones: [
                        .init(point: Point(r: 2, c: 6), stone: .black),
                        .init(point: Point(r: 3, c: 5), stone: .black),
                        .init(point: Point(r: 4, c: 6), stone: .black),
                        .init(point: Point(r: 2, c: 5), stone: .white),
                        .init(point: Point(r: 3, c: 6), stone: .white),
                        .init(point: Point(r: 3, c: 7), stone: .white),
                        .init(point: Point(r: 4, c: 7), stone: .white)
                    ],
                    lastMove: Point(r: 3, c: 6),
                    highlightPoints: [Point(r: 3, c: 6)],
                    caption: "白棋可以从缺陷处破眼。能被破掉的眼，就是假眼。"
                )
            ]
        ),
        TutorialLesson(
            id: 8,
            title: "简单死活",
            explanation: "一块棋有两个独立真眼，就活；只有一个眼，常常会死。",
            task: "按演示看：一个眼和两个眼的区别。",
            initialStones: [
                .init(point: Point(r: 3, c: 3), stone: .black),
                .init(point: Point(r: 3, c: 4), stone: .black),
                .init(point: Point(r: 3, c: 5), stone: .black),
                .init(point: Point(r: 4, c: 3), stone: .black),
                .init(point: Point(r: 4, c: 5), stone: .black),
                .init(point: Point(r: 5, c: 3), stone: .black),
                .init(point: Point(r: 5, c: 4), stone: .black),
                .init(point: Point(r: 5, c: 5), stone: .black),
                .init(point: Point(r: 2, c: 4), stone: .white),
                .init(point: Point(r: 4, c: 2), stone: .white),
                .init(point: Point(r: 4, c: 6), stone: .white),
                .init(point: Point(r: 6, c: 4), stone: .white)
            ],
            currentPlayer: .black,
            action: .watchDemo,
            wrongHint: "",
            successFeedback: "死活的第一判断：这块棋能不能做出两个独立真眼。",
            demoFrames: [
                TutorialDemoFrame(
                    stones: [
                        .init(point: Point(r: 3, c: 3), stone: .black),
                        .init(point: Point(r: 3, c: 4), stone: .black),
                        .init(point: Point(r: 3, c: 5), stone: .black),
                        .init(point: Point(r: 4, c: 3), stone: .black),
                        .init(point: Point(r: 4, c: 5), stone: .black),
                        .init(point: Point(r: 5, c: 3), stone: .black),
                        .init(point: Point(r: 5, c: 4), stone: .black),
                        .init(point: Point(r: 5, c: 5), stone: .black),
                        .init(point: Point(r: 2, c: 4), stone: .white),
                        .init(point: Point(r: 4, c: 2), stone: .white),
                        .init(point: Point(r: 4, c: 6), stone: .white),
                        .init(point: Point(r: 6, c: 4), stone: .white)
                    ],
                    highlightPoints: [Point(r: 4, c: 4)],
                    caption: "这里只有一个内部空点。白棋以后填进来，黑棋会没有眼。"
                ),
                TutorialDemoFrame(
                    stones: [
                        .init(point: Point(r: 3, c: 3), stone: .black),
                        .init(point: Point(r: 3, c: 4), stone: .black),
                        .init(point: Point(r: 3, c: 5), stone: .black),
                        .init(point: Point(r: 3, c: 6), stone: .black),
                        .init(point: Point(r: 4, c: 3), stone: .black),
                        .init(point: Point(r: 4, c: 6), stone: .black),
                        .init(point: Point(r: 5, c: 3), stone: .black),
                        .init(point: Point(r: 5, c: 4), stone: .black),
                        .init(point: Point(r: 5, c: 5), stone: .black),
                        .init(point: Point(r: 5, c: 6), stone: .black),
                        .init(point: Point(r: 2, c: 4), stone: .white),
                        .init(point: Point(r: 2, c: 5), stone: .white),
                        .init(point: Point(r: 4, c: 2), stone: .white),
                        .init(point: Point(r: 4, c: 7), stone: .white),
                        .init(point: Point(r: 6, c: 4), stone: .white),
                        .init(point: Point(r: 6, c: 5), stone: .white)
                    ],
                    highlightPoints: [Point(r: 4, c: 4), Point(r: 4, c: 5)],
                    caption: "这里有两个分开的空点。白棋一次只能填一个，黑棋还能保住另一个。"
                ),
                TutorialDemoFrame(
                    stones: [
                        .init(point: Point(r: 3, c: 3), stone: .black),
                        .init(point: Point(r: 3, c: 4), stone: .black),
                        .init(point: Point(r: 3, c: 5), stone: .black),
                        .init(point: Point(r: 3, c: 6), stone: .black),
                        .init(point: Point(r: 4, c: 3), stone: .black),
                        .init(point: Point(r: 4, c: 6), stone: .black),
                        .init(point: Point(r: 5, c: 3), stone: .black),
                        .init(point: Point(r: 5, c: 4), stone: .black),
                        .init(point: Point(r: 5, c: 5), stone: .black),
                        .init(point: Point(r: 5, c: 6), stone: .black),
                        .init(point: Point(r: 4, c: 4), stone: .white)
                    ],
                    lastMove: Point(r: 4, c: 4),
                    highlightPoints: [Point(r: 4, c: 5)],
                    caption: "白棋填掉一个眼后，另一个眼还在。两个独立真眼就是活棋。"
                )
            ]
        ),
        TutorialLesson(
            id: 9,
            title: "地盘和胜负",
            explanation: "围住的空点是地。终局比较：地盘、提子，白棋还加贴目。",
            task: "按演示看：哪些空点算地，胜负怎么比较。",
            initialStones: [
                .init(point: Point(r: 1, c: 1), stone: .black),
                .init(point: Point(r: 1, c: 2), stone: .black),
                .init(point: Point(r: 1, c: 3), stone: .black),
                .init(point: Point(r: 2, c: 1), stone: .black),
                .init(point: Point(r: 3, c: 1), stone: .black),
                .init(point: Point(r: 6, c: 6), stone: .white),
                .init(point: Point(r: 6, c: 7), stone: .white),
                .init(point: Point(r: 7, c: 6), stone: .white),
                .init(point: Point(r: 7, c: 7), stone: .white)
            ],
            currentPlayer: .black,
            action: .watchDemo,
            wrongHint: "",
            successFeedback: "先看谁围住更多空点，再加上提子和贴目，就是胜负判断。",
            demoFrames: [
                TutorialDemoFrame(
                    stones: [
                        .init(point: Point(r: 1, c: 1), stone: .black),
                        .init(point: Point(r: 1, c: 2), stone: .black),
                        .init(point: Point(r: 1, c: 3), stone: .black),
                        .init(point: Point(r: 2, c: 1), stone: .black),
                        .init(point: Point(r: 3, c: 1), stone: .black),
                        .init(point: Point(r: 3, c: 2), stone: .black),
                        .init(point: Point(r: 3, c: 3), stone: .black)
                    ],
                    blackTerritory: [Point(r: 2, c: 2), Point(r: 2, c: 3)],
                    caption: "黑棋围住的空交叉点，算黑方地盘。这里黑有 2 目。"
                ),
                TutorialDemoFrame(
                    stones: [
                        .init(point: Point(r: 5, c: 5), stone: .white),
                        .init(point: Point(r: 5, c: 6), stone: .white),
                        .init(point: Point(r: 5, c: 7), stone: .white),
                        .init(point: Point(r: 6, c: 5), stone: .white),
                        .init(point: Point(r: 7, c: 5), stone: .white),
                        .init(point: Point(r: 7, c: 6), stone: .white),
                        .init(point: Point(r: 7, c: 7), stone: .white)
                    ],
                    whiteTerritory: [Point(r: 6, c: 6), Point(r: 6, c: 7)],
                    caption: "白棋围住的空点，算白方地盘。这里白也有 2 目。"
                ),
                TutorialDemoFrame(
                    stones: [
                        .init(point: Point(r: 1, c: 1), stone: .black),
                        .init(point: Point(r: 1, c: 2), stone: .black),
                        .init(point: Point(r: 1, c: 3), stone: .black),
                        .init(point: Point(r: 2, c: 1), stone: .black),
                        .init(point: Point(r: 3, c: 1), stone: .black),
                        .init(point: Point(r: 3, c: 2), stone: .black),
                        .init(point: Point(r: 3, c: 3), stone: .black),
                        .init(point: Point(r: 5, c: 5), stone: .white),
                        .init(point: Point(r: 5, c: 6), stone: .white),
                        .init(point: Point(r: 5, c: 7), stone: .white),
                        .init(point: Point(r: 6, c: 5), stone: .white),
                        .init(point: Point(r: 7, c: 5), stone: .white),
                        .init(point: Point(r: 7, c: 6), stone: .white),
                        .init(point: Point(r: 7, c: 7), stone: .white)
                    ],
                    blackTerritory: [Point(r: 2, c: 2), Point(r: 2, c: 3)],
                    whiteTerritory: [Point(r: 6, c: 6), Point(r: 6, c: 7)],
                    caption: "终局常用算法：黑 = 黑地 + 黑提子；白 = 白地 + 白提子 + 贴目。"
                )
            ]
        ),
        TutorialLesson(
            id: 10,
            title: "进入正式训练",
            explanation: "你已经见过落子、气、提子、禁手、劫、眼和胜负。",
            task: "点一下天元，完成新手村。",
            initialStones: [
                .init(point: Point(r: 2, c: 2), stone: .black),
                .init(point: Point(r: 2, c: 6), stone: .white),
                .init(point: Point(r: 6, c: 2), stone: .white),
                .init(point: Point(r: 6, c: 6), stone: .black)
            ],
            currentPlayer: .black,
            correctPoint: Point(r: 4, c: 4),
            action: .inspectPoint,
            wrongHint: "天元还是棋盘最中央的交叉点。",
            successFeedback: "完成！现在可以开始对局，或去做第一组死活题。"
        )
    ]
}
