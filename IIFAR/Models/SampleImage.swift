import Foundation

struct SampleImage: Identifiable, Hashable {
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
        let urlString = "\(iiifBaseURL)/full/!\(maxDimension),\(maxDimension)/0/default.jpg"
        return URL(string: urlString)
    }

    func iiifTileURL(region: (x: Int, y: Int, w: Int, h: Int), size: (w: Int, h: Int)) -> URL? {
        let urlString = "\(iiifBaseURL)/\(region.x),\(region.y),\(region.w),\(region.h)/\(size.w),\(size.h)/0/default.jpg"
        return URL(string: urlString)
    }
}

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
            id: "sho",
            name: "琉球国之図",
            description: "沖縄美ら島財団所蔵。嘉慶元年（1796年）製作。",
            detail: "嘉慶元年（1796年）に琉球独自の測量技術で作られた精密な絵図で、首里王府の命により測量家の高原景宅が製作したと考えられています。沖縄本島と周辺諸島を描き、間切や島ごとに美しく塗り分けられた芸術作品としての価値も備えた歴史史料です。",
            sizeLabel: "大",
            iiifBaseURL: "https://cantaloupe.lab.hi.u-tokyo.ac.jp/iiif/2/clioimg%2Fsho.tif",
            pixelWidth: 25167,
            pixelHeight: 12483,
            realWidthCm: 96.8,
            realHeightCm: 47.3
        ),
        SampleImage(
            id: "ryukyu",
            name: "琉球国図",
            description: "沖縄県立博物館・美術館所蔵。元禄9年（1696年）奉納。",
            detail: "縦175.8cm、横87.8cmにおよぶ掛幅の大型絵図です。元禄9年（1696）に大宰府天満宮に奉納されたもので、九州南部から沖縄本島を中心とする琉球の島々と航路が描かれています。「海東諸国紀」所収図と近似しつつも、より多くの情報を含み、1453年に博多商人道安から朝鮮王朝に献上された絵図の系譜に近いと推測されています。現状は南を上にして仕立てられています。",
            sizeLabel: "特大",
            iiifBaseURL: "https://cantaloupe.lab.hi.u-tokyo.ac.jp/iiif/2/clioimg%2Fcbd4f3b8-e6ec-4c15-9ffc-79badb88127f.tif",
            pixelWidth: 9449,
            pixelHeight: 20724,
            realWidthCm: 87.8,
            realHeightCm: 175.8
        ),
    ]
}
