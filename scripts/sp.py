import os
import sentencepiece

home_dir = os.path.expanduser("~")
text_tokenizer = sentencepiece.SentencePieceProcessor(home_dir + "/tmp/tokenizer_spm_48k_multi6_2.model")

text_tokens = [1231, 3, 3, 2303, 36146, 447, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 0, 371, 3, 3, 3, 3, 3, 0, 365, 0, 2610, 0, 367, 0, 410, 0, 4788, 3, 3, 0, 4235, 362, 3, 3, 3, 0, 542, 3, 3, 0, 365, 0, 4522, 3, 0, 14662, 366, 1307, 451, 3, 3, 0, 4584, 366, 3, 0, 367, 0, 365, 0, 1869, 364, 3, 3, 3, 3, 3, 3, 3, 0, 717, 3753, 3, 0, 369, 0, 18187, 3, 3, 3, 3, 0, 14995, 3, 3, 3, 0, 1401, 3, 3, 0, 14561, 362, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 0, 10385, 3, 3, 0, 581, 3, 0, 493, 3, 0, 14995, 364, 3, 3, 3, 3, 3, 3, 0, 14561, 0, 387, 3, 0, 1301, 3, 0, 392, 0, 11346, 362, 3, 3, 3, 3, 3, 3, 0, 369, 3, 0, 3317, 3, 0, 12822, 3, 3, 3, 0, 385, 3, 0, 673, 0, 505, 0, 1534, 3, 0, 373, 0, 1448, 3, 3, 3, 0, 365, 3, 0, 2365, 3, 0, 367, 364, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 0, 2700, 3, 0, 2613, 362, 3, 3, 3, 3, 3, 0, 664, 3, 0, 365, 0, 33955, 3, 0, 367, 0, 365, 0, 8208, 362, 3, 3, 3, 3, 0, 673, 0, 486, 0, 28591, 3, 0, 559, 0, 409, 0, 365, 0, 3638, 362, 3, 3, 3, 3, 3, 3, 3, 0, 8284, 3, 3, 3, 0, 503, 0, 502, 0, 387, 0, 484, 3, 0, 373, 0, 585, 3, 0, 3546, 364, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 0, 1054, 3, 3, 3, 0, 10039, 362, 3, 3, 3, 3, 3, 3, 0, 365, 3, 3, 0, 4235, 3, 0, 11223, 451, 3, 3, 3, 0, 371, 3, 0, 5103, 478, 3, 0, 8208, 3471, 362, 3, 3, 3, 3, 3, 3, 3, 0, 14561, 3, 0, 4223, 3, 3, 3, 3, 0, 369, 3, 0, 29336, 0, 673, 3, 0, 505, 0, 1313, 3, 0, 1281, 3, 0, 701, 364, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 0, 423, 3, 3, 0, 365, 0, 1971, 3, 3, 0, 10400, 3, 0, 369, 0, 7362, 375, 26668, 3, 3, 3, 0, 14021, 3, 3, 0, 385, 3, 0, 7931, 451, 3, 3, 0, 365, 0, 2613, 3, 0, 9555, 364, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 0, 27196, 411, 0, 373, 530, 3, 0, 16550, 362, 3, 3, 3, 3, 3, 3, 0, 14561, 0, 17504, 3, 3, 3, 0, 365, 3, 0, 14021, 362, 3, 0, 370, 3, 3, 3, 0, 384, 3, 0, 365, 0, 499, 3, 0, 497, 3, 3, 3, 3, 3, 3, 3, 0, 47995, 3, 3, 3, 3, 3, 0, 585, 0, 11346, 364, 3, 3, 3, 3, 3, 3, 3, 0, 616, 3, 3, 0, 673, 0, 27937, 3, 3, 0, 365, 0, 796, 378, 366, 1114, 3, 3, 3, 0, 392, 0, 585, 0, 641, 5396, 362, 3, 3, 3, 3, 3, 0, 365, 0, 14021, 3, 3, 0, 42965, 434, 362, 3, 3, 3, 3, 3, 3, 0, 370, 0, 365, 0, 8482, 3, 3]
text_tokens = [t for t in text_tokens if t not in [0, 3]]
out = text_tokenizer.decode(text_tokens)
print(out)