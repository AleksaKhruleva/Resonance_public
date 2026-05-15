import Core

enum QuestionAnswerPreview {
    static let limit = 3

    static func limitedAnswers(_ answers: [Answer]) -> [Answer] {
        Array(answers.prefix(limit))
    }

    static func limitedQuestion(_ question: Question) -> Question {
        var question = question
        question.answers = limitedAnswers(question.answers)
        return question
    }

    static func limitedQuestions(_ questions: [Question]) -> [Question] {
        questions.map(limitedQuestion)
    }
}
