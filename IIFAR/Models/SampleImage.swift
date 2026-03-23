import Foundation

struct SampleImage: Identifiable {
    let id: String
    let name: String
    let description: String
    let detail: String
    let sizeLabel: String
    let iiifBaseURL: String
    let pixelWidth: Int
    let pixelHeight: Int
    let realWidthCm: Double
    let realHeightCm: Double
    var tileSize: Int = 512
    var scaleFactors: [Int] = [1, 2, 4, 8, 16, 32, 64, 128]
    /// IIIF Level 0 servers only support pre-computed sizes.
    /// If set, use exact size instead of !max,max syntax.
    var overviewSize: (w: Int, h: Int)?

    var cmPerPixelX: Double { realWidthCm / Double(pixelWidth) }
    var cmPerPixelY: Double { realHeightCm / Double(pixelHeight) }
    var realWidthMeters: Double { realWidthCm / 100.0 }
    var realHeightMeters: Double { realHeightCm / 100.0 }

    var sizeDescription: String {
        if realWidthCm >= 100 || realHeightCm >= 100 {
            return String(format: "%.1f×%.1f m", realWidthCm / 100, realHeightCm / 100)
        }
        return String(format: "%.1f×%.1f cm", realWidthCm, realHeightCm)
    }

    var scaleDescription: String {
        String(format: "%.4f×%.4f cm/px", cmPerPixelX, cmPerPixelY)
    }

    func iiifImageURL(maxDimension: Int) -> URL? {
        if let size = overviewSize {
            // Level 0: use exact pre-computed size
            let urlString = "\(iiifBaseURL)/full/\(size.w),\(size.h)/0/default.jpg"
            return URL(string: urlString)
        }
        // Level 1+: use best-fit syntax
        let urlString = "\(iiifBaseURL)/full/!\(maxDimension),\(maxDimension)/0/default.jpg"
        return URL(string: urlString)
    }

    func iiifThumbnailURL() -> URL? {
        if let size = overviewSize {
            // Use a smaller pre-computed size for thumbnail
            let tw = max(size.w / 2, 1)
            let th = max(size.h / 2, 1)
            let urlString = "\(iiifBaseURL)/full/\(tw),\(th)/0/default.jpg"
            return URL(string: urlString)
        }
        let urlString = "\(iiifBaseURL)/full/!400,400/0/default.jpg"
        return URL(string: urlString)
    }

    func iiifTileURL(region: (x: Int, y: Int, w: Int, h: Int), size: (w: Int, h: Int)) -> URL? {
        let urlString = "\(iiifBaseURL)/\(region.x),\(region.y),\(region.w),\(region.h)/\(size.w),\(size.h)/0/default.jpg"
        return URL(string: urlString)
    }

    // MARK: - Hashable (based on id only, since overviewSize tuple is not Hashable)
    static func == (lhs: SampleImage, rhs: SampleImage) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension SampleImage: Hashable {}

extension SampleImage {
    static let samples: [SampleImage] = [
        SampleImage(
            id: "kaitou",
            name: "海東諸国紀",
            description: "東京大学史料編纂所所蔵。正徳7年（1512）善本。",
            detail: "朝鮮成宗2年（1471）に申叔舟が編纂した海東諸国（日本国・琉球国）の研究書です。史料編纂所本は朝鮮活字版の冊子で、表紙裏の内賜記に「正徳7年（1512）」の年紀があることから善本とされています。所収図は全10点あり、冒頭の「海東諸国総図」は9点の絵図を合成した一図です。日本部分は行基図様式をベースに、九州・琉球部分は1453年に博多商人道安から朝鮮王朝に献上された絵図をベースにしていると考えられています。",
            sizeLabel: "小",
            iiifBaseURL: "https://cantaloupe.lab.hi.u-tokyo.ac.jp/iiif/2/clioimg%2F6ac7a5b6-1a7a-4371-92fa-5b43e689ac52.tif",
            pixelWidth: 4474,
            pixelHeight: 3918,
            realWidthCm: 32.6,
            realHeightCm: 21.2
        ),
        SampleImage(
            id: "wakozukan",
            name: "倭寇図巻",
            description: "東京大学史料編纂所所蔵。明代末期（〜17世紀前半）製作。",
            detail: "20世紀初頭に中国から日本に渡った絵巻で、倭寇との戦いを着色で描いた唯一の史料として教科書にもしばしば掲載されてきました。元の題簽「明仇十洲台湾奏凱図」は内容にそぐわないとして、史料編纂所入架時に「倭寇図巻」と改称。中国国家博物館所蔵「抗倭図巻」との関連が近年の研究で明らかにされています。",
            sizeLabel: "中",
            iiifBaseURL: "https://www.hi.u-tokyo.ac.jp/collection/digitalgallery/wakozukan/data/files/tile/wakozukan",
            pixelWidth: 90916,
            pixelHeight: 6615,
            realWidthCm: 523.0,
            realHeightCm: 32.0,
            tileSize: 1024,
            scaleFactors: [1, 2, 4, 8, 16, 32, 64],
            overviewSize: (w: 710, h: 52)
        ),
        SampleImage(
            id: "shoho",
            name: "正保琉球国悪鬼納島絵図写",
            description: "東京大学史料編纂所所蔵（国宝・島津家文書）。",
            detail: "正保の国絵図は1644年に江戸幕府が全国に命じて製作を開始した国ごとの絵図です。琉球国絵図は奄美諸島〜八重山諸島までの島々を3舗に分けて仕上げた大型絵図で、幕府提出の原本は所在不明ですが、約50年後に薩摩藩が原寸大で忠実に写したものが東京大学史料編纂所の国宝「島津家文書」に残っています。大型琉球絵図としては最古のもので、地形・地名・石高・交通など豊富な情報が盛り込まれています。本図は3舗のうち②悪鬼納島（沖縄本島）の絵図です。",
            sizeLabel: "大",
            iiifBaseURL: "https://www.hi.u-tokyo.ac.jp/collection/digitalgallery/ryukyu/data/files/tile/0002",
            pixelWidth: 49797,
            pixelHeight: 28435,
            realWidthCm: 621.6,
            realHeightCm: 353.7,
            tileSize: 1024,
            scaleFactors: [1, 2, 4, 8, 16, 32],
            overviewSize: (w: 778, h: 444)
        ),
    ]
}
